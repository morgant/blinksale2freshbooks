require "active_support/core_ext/object/blank"

module Blinksale2FreshBooks

  class Migration

    attr_accessor :src, :dst, :attrs

    def initialize(src, dst)
      raise ArgumentError if src.nil? || dst.nil?
      @src = src
      @dst = dst
      @attrs = []
    end

    def add_attr_association(description, src_attr, dst_attr = nil)
      raise ArgumentError if src_attr.blank?
      dst_attr = src_attr if dst_attr.blank?
      @attrs << {
        src: src_attr,
        dst: dst_attr,
        desc: description
      }
    end

    def same?
      no_match = @attrs.detect {|f| !attrs_match?(f[:src], f[:dst], f[:desc])}
      (no_match.length > 0) ? true : false
    end

    private

    def attrs_match?(src_attr, dst_attr, description)
      raise ArgumentError if src_attr.blank? || dst_attr.blank?
      src_val = @src.send(src_attr)
      dst_val = @dst.send(dst_attr)
      if !(src_val.blank? && dst_val.blank?) && (src_val != src_val)
        puts "#{description} attrs don't match! #{src_attr} != #{dst_attr} ('#{src_val}' != '#{dst_val}')
        false
      else
        puts "#{description} attrs match. #{src_attr} != #{dst_attr} ('#{src_val}' == '#{dst_val}')
        true
      end
    end

  end

end