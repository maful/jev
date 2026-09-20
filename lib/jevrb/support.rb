# frozen_string_literal: true

module Jevrb
  module Support
    module_function

    def normalize_json_content(value, path:, allow_nil: false)
      return nil if value.nil? && allow_nil

      unless value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array)
        raise ArgumentError, "#{path} must be a string, hash, or array"
      end

      normalize_json_value(value, path: path)
    end

    def normalize_json_value(value, path:)
      case value
      when String
        value.dup.freeze
      when Integer, TrueClass, FalseClass, NilClass
        value
      when Float
        raise ArgumentError, "#{path} must contain only finite numbers" unless value.finite?

        value
      when Array
        value.each_with_index.map do |entry, index|
          normalize_json_value(entry, path: "#{path}[#{index}]")
        end.freeze
      when Hash
        normalize_json_hash(value, path: path)
      else
        raise ArgumentError, "#{path} contains a non-JSON value: #{value.class}"
      end
    end

    def normalize_json_hash(value, path:)
      value.each_with_object({}) do |(key, entry), result|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise ArgumentError, "#{path} contains a non-string key: #{key.inspect}"
        end

        normalized_key = key.to_s
        raise ArgumentError, "#{path} contains duplicate key #{normalized_key.inspect}" if result.key?(normalized_key)

        result[normalized_key.freeze] = normalize_json_value(entry, path: "#{path}.#{normalized_key}")
      end.freeze
    end

    def required_hash_value(hash, key, path:)
      return hash[key] if hash.key?(key)

      raise KeyError, "missing required field #{path}.#{key}"
    end
  end
end
