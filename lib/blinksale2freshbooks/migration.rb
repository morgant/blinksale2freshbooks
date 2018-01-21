require "active_support/core_ext/object/blank"

module Blinksale2FreshBooks

  class Migration

    attr_accessor :src, :dst, :attrs

    def initialize(src, dst)
      raise ArgumentError if src.nil?
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

    def migration_hash
      hash = {}
      @attrs.each do |attr|
        hash[attr[:dst]] = @src.send(attr[:src])
      end
      hash
    end

    def same?
      differing = differing_attrs
      differing.nil? || differing.empty?
    end

    def update
      unless same?
        differing_attrs.each do |attr|
          migrate_attr(attr[:src], attr[:dst], attr[:desc])
        end
      end
    end

    private

    def attr_match?(src_attr, dst_attr, description)
      raise ArgumentError if src_attr.blank? || dst_attr.blank?
      src_val = @src.send(src_attr)
      dst_val = (@dst.nil?) ? nil : @dst.send(dst_attr)
      if !(src_val.blank? && dst_val.blank?) && (src_val != dst_val)
        puts "#{description} attrs don't match! #{src_attr} != #{dst_attr} ('#{src_val}' != '#{dst_val}')"
        false
      else
        #puts "#{description} attrs match. #{src_attr} == #{dst_attr} ('#{src_val}' == '#{dst_val}')"
        true
      end
    end

    def differing_attrs
      @attrs.find_all {|attr| !attr_match?(attr[:src], attr[:dst], attr[:desc])}
    end

    def migrate_attr(src_attr, dst_attr, description)
      raise ArgumentError if @dst.nil? || src_attr.blank? || dst_attr.blank?
      src_val = @src.send(src_attr)
      @dst.send("#{dst_attr}=", src_val)
      puts "#{description} attr migrated (#{src_attr} to #{dst_attr}): '#{src_val}'"
    end

  end

end