# frozen_string_literal: true

require 'jwt'
require 'faraday'
require 'openssl'
require 'base64'

class KiketSDK
  ##
  # JWT verification for webhook payloads.
  # Verifies runtime tokens are signed by Kiket using ES256 (ECDSA P-256).
  module Auth
    class AuthenticationError < StandardError; end

    ALGORITHM = 'ES256'
    ISSUER = 'kiket.dev'
    JWKS_CACHE_TTL = 3600 # 1 hour

    module_function

    ##
    # Verify the runtime token JWT from the payload.
    # @param payload [Hash] The webhook payload containing authentication.runtime_token
    # @param base_url [String] Base URL for fetching JWKS
    # @return [Hash] The decoded JWT payload
    def verify_runtime_token(payload, base_url)
      auth = payload.is_a?(Hash) ? (payload['authentication'] || {}) : {}
      token = auth['runtime_token']

      raise AuthenticationError, 'Missing runtime_token in payload' if token.nil? || token.empty?

      decode_jwt(token, base_url)
    end

    ##
    # Decode and verify a JWT token using the public key from JWKS.
    # @param token [String] The JWT token to verify
    # @param base_url [String] Base URL for fetching JWKS
    # @return [Hash] The decoded payload
    def decode_jwt(token, base_url)
      jwks = fetch_jwks(base_url)
      public_key = extract_public_key(jwks)

      decoded = JWT.decode(
        token,
        public_key,
        true,
        {
          algorithm: ALGORITHM,
          iss: ISSUER,
          verify_iss: true,
          verify_iat: true,
          verify_exp: true
        }
      )

      decoded.first
    rescue JWT::ExpiredSignature
      raise AuthenticationError, 'Runtime token has expired'
    rescue JWT::InvalidIssuerError
      raise AuthenticationError, 'Invalid token issuer'
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Invalid token: #{e.message}"
    end

    ##
    # Fetch JWKS from the well-known endpoint with caching.
    # @param base_url [String] Base URL for fetching JWKS
    # @return [Hash] The JWKS response
    def fetch_jwks(base_url)
      @jwks_cache ||= {}
      cache_key = base_url
      cached = @jwks_cache[cache_key]

      if cached && (Time.now - cached[:fetched_at]) < JWKS_CACHE_TTL
        return cached[:jwks]
      end

      jwks_url = "#{base_url.chomp('/')}/.well-known/jwks.json"
      response = Faraday.get(jwks_url) do |req|
        req.options.timeout = 10
        req.options.open_timeout = 5
      end

      raise AuthenticationError, "Failed to fetch JWKS: #{response.status}" unless response.success?

      jwks = JSON.parse(response.body)
      @jwks_cache[cache_key] = { jwks: jwks, fetched_at: Time.now }
      jwks
    rescue Faraday::Error => e
      raise AuthenticationError, "Failed to fetch JWKS: #{e.message}"
    rescue JSON::ParserError
      raise AuthenticationError, 'Invalid JWKS response'
    end

    ##
    # Extract the EC public key from JWKS.
    # @param jwks [Hash] The JWKS response
    # @return [OpenSSL::PKey::EC] The public key
    def extract_public_key(jwks)
      keys = jwks['keys'] || []
      key_data = keys.find { |k| k['alg'] == ALGORITHM && k['use'] == 'sig' }

      raise AuthenticationError, 'No suitable signing key found in JWKS' if key_data.nil?

      build_ec_public_key(key_data)
    end

    ##
    # Build an EC public key from JWK parameters.
    # @param jwk [Hash] The JWK key data with x and y coordinates
    # @return [OpenSSL::PKey::EC] The public key
    def build_ec_public_key(jwk)
      x = Base64.urlsafe_decode64(jwk['x'])
      y = Base64.urlsafe_decode64(jwk['y'])

      # Build uncompressed point: 0x04 || x || y
      point_hex = '04' + x.unpack1('H*') + y.unpack1('H*')
      point_bn = OpenSSL::BN.new(point_hex, 16)

      group = OpenSSL::PKey::EC::Group.new('prime256v1')
      point = OpenSSL::PKey::EC::Point.new(group, point_bn)

      # Create EC key with public point
      key = OpenSSL::PKey::EC.new(group)
      key.public_key = point
      key
    end

    ##
    # Clear the JWKS cache (useful for testing or key rotation).
    def clear_jwks_cache
      @jwks_cache = {}
    end
  end
end
