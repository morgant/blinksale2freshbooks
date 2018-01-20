require "active_support/core_ext/object/blank"

module Blinksale2FreshBooks

  class Migration

    attr_accessor :src, :dst, :fields

    def initialize(src, dst)
      raise ArgumentError if src.nil? || dst.nil?
      @src = src
      @dst = dst
      @fields = []
    end

    def add_field_association(description, src_field, dst_field = nil)
      raise ArgumentError if src_field.blank?
      dst_field = src_field if dst_field.blank?
      @fields << {
        src: src_field,
        dst: dst_field,
        desc: description
      }
    end

    def same?
      no_match = @fields.detect {|f| !fields_match?(f[:src], f[:dst], f[:desc])}
      (no_match.length > 0) ? true : false
    end

    private

    def fields_match?(src_field, dst_field, description)
      raise ArgumentError if src_field.blank? || dst_field.blank?
      src_val = @src.send(src_field)
      dst_val = @dst.send(dst_field)
      if !(src_val.blank? && dst_val.blank?) && (src_val != src_val)
        puts "#{description} fields don't match! #{src_field} != #{dst_field} ('#{src_val}' != '#{dst_val}')
        false
      else
        puts "#{description} fields match. #{src_field} != #{dst_field} ('#{src_val}' == '#{dst_val}')
        true
      end
    end

  end

end