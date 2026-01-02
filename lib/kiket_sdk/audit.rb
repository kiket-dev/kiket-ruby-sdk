# frozen_string_literal: true

require "json"
require "digest"

module KiketSdk
  # Client for blockchain audit verification operations.
  class AuditClient
    # Represents a blockchain anchor containing a batch of audit records.
    BlockchainAnchor = Struct.new(
      :id, :merkle_root, :leaf_count, :first_record_at, :last_record_at,
      :network, :status, :tx_hash, :block_number, :block_timestamp,
      :confirmed_at, :explorer_url, :created_at, :records,
      keyword_init: true
    )

    # Represents a Merkle proof for an audit record.
    BlockchainProof = Struct.new(
      :record_id, :record_type, :content_hash, :anchor_id, :merkle_root,
      :leaf_index, :leaf_count, :proof, :network, :tx_hash, :block_number,
      :block_timestamp, :verified, :verification_url,
      keyword_init: true
    )

    # Result of a blockchain verification.
    VerificationResult = Struct.new(
      :verified, :proof_valid, :blockchain_verified, :content_hash,
      :merkle_root, :leaf_index, :block_number, :block_timestamp,
      :network, :explorer_url, :error,
      keyword_init: true
    )

    def initialize(client)
      @client = client
    end

    # List blockchain anchors for the organization.
    #
    # @param status [String, nil] Filter by status (pending, submitted, confirmed, failed)
    # @param network [String, nil] Filter by network (polygon_amoy, polygon_mainnet)
    # @param from [Time, nil] Filter anchors created after this date
    # @param to [Time, nil] Filter anchors created before this date
    # @param page [Integer] Page number (1-indexed)
    # @param per_page [Integer] Results per page (max 100)
    # @return [Hash] { anchors: Array<BlockchainAnchor>, pagination: Hash }
    def list_anchors(status: nil, network: nil, from: nil, to: nil, page: 1, per_page: 25)
      params = { page: page, per_page: per_page }
      params[:status] = status if status
      params[:network] = network if network
      params[:from] = from.iso8601 if from
      params[:to] = to.iso8601 if to

      response = @client.get("/api/v1/audit/anchors", params)
      data = response.body

      {
        anchors: data["anchors"].map { |a| parse_anchor(a) },
        pagination: data["pagination"]
      }
    end

    # Get details of a specific anchor by merkle root.
    #
    # @param merkle_root [String] The merkle root (hex string with 0x prefix)
    # @param include_records [Boolean] Whether to include the list of records
    # @return [BlockchainAnchor]
    def get_anchor(merkle_root, include_records: false)
      params = include_records ? { include_records: "true" } : {}
      response = @client.get("/api/v1/audit/anchors/#{merkle_root}", params)
      parse_anchor(response.body)
    end

    # Get the blockchain proof for a specific audit record.
    #
    # @param record_id [Integer] The ID of the audit record
    # @param record_type [String] Type of record ("AuditLog" or "AIAuditLog"), defaults to "AuditLog"
    # @return [BlockchainProof]
    def get_proof(record_id, record_type: "AuditLog")
      params = record_type != "AuditLog" ? { record_type: record_type } : {}
      response = @client.get("/api/v1/audit/records/#{record_id}/proof", params)
      parse_proof(response.body)
    end

    # Verify a blockchain proof via the API.
    #
    # @param proof [BlockchainProof, Hash] Proof to verify
    # @return [VerificationResult]
    def verify(proof)
      payload = if proof.is_a?(BlockchainProof)
        {
          content_hash: proof.content_hash,
          merkle_root: proof.merkle_root,
          proof: proof.proof,
          leaf_index: proof.leaf_index,
          tx_hash: proof.tx_hash
        }
      else
        proof
      end

      response = @client.post("/api/v1/audit/verify", payload)
      data = response.body

      VerificationResult.new(
        verified: data["verified"],
        proof_valid: data["proof_valid"],
        blockchain_verified: data["blockchain_verified"],
        content_hash: data["content_hash"],
        merkle_root: data["merkle_root"],
        leaf_index: data["leaf_index"],
        block_number: data["block_number"],
        block_timestamp: parse_timestamp(data["block_timestamp"]),
        network: data["network"],
        explorer_url: data["explorer_url"],
        error: data["error"]
      )
    end

    # Compute the content hash for a record (for local verification).
    #
    # @param data [Hash] Record data
    # @return [String] Hex string with 0x prefix
    def self.compute_content_hash(data)
      canonical = JSON.generate(data.sort.to_h)
      digest = Digest::SHA256.hexdigest(canonical)
      "0x#{digest}"
    end

    # Verify a Merkle proof locally without making an API call.
    #
    # @param content_hash [String] Hash of the record content
    # @param proof_path [Array<String>] Array of sibling hashes
    # @param leaf_index [Integer] Position of the leaf in the tree
    # @param merkle_root [String] Expected root hash
    # @return [Boolean] True if the proof is valid
    def self.verify_proof_locally(content_hash:, proof_path:, leaf_index:, merkle_root:)
      normalize_hash = ->(h) {
        hex = h.start_with?("0x") ? h[2..] : h
        [hex].pack("H*")
      }

      hash_pair = ->(left, right) {
        left, right = right, left if left > right
        Digest::SHA256.digest(left + right)
      }

      current = normalize_hash.call(content_hash)
      idx = leaf_index

      proof_path.each do |sibling_hex|
        sibling = normalize_hash.call(sibling_hex)
        current = if idx.even?
          hash_pair.call(current, sibling)
        else
          hash_pair.call(sibling, current)
        end
        idx /= 2
      end

      expected = normalize_hash.call(merkle_root)
      current == expected
    end

    private

    def parse_anchor(data)
      BlockchainAnchor.new(
        id: data["id"],
        merkle_root: data["merkle_root"],
        leaf_count: data["leaf_count"],
        first_record_at: parse_timestamp(data["first_record_at"]),
        last_record_at: parse_timestamp(data["last_record_at"]),
        network: data["network"],
        status: data["status"],
        tx_hash: data["tx_hash"],
        block_number: data["block_number"],
        block_timestamp: parse_timestamp(data["block_timestamp"]),
        confirmed_at: parse_timestamp(data["confirmed_at"]),
        explorer_url: data["explorer_url"],
        created_at: parse_timestamp(data["created_at"]),
        records: data["records"]
      )
    end

    def parse_proof(data)
      BlockchainProof.new(
        record_id: data["record_id"],
        record_type: data["record_type"],
        content_hash: data["content_hash"],
        anchor_id: data["anchor_id"],
        merkle_root: data["merkle_root"],
        leaf_index: data["leaf_index"],
        leaf_count: data["leaf_count"],
        proof: data["proof"],
        network: data["network"],
        tx_hash: data["tx_hash"],
        block_number: data["block_number"],
        block_timestamp: parse_timestamp(data["block_timestamp"]),
        verified: data["verified"],
        verification_url: data["verification_url"]
      )
    end

    def parse_timestamp(value)
      return nil unless value
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
