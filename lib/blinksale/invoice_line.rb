require 'blinksale/rest_client'

class Blinksale < REST::Client

  module Invoice
    module ResourceMethods
      def lines
         all = []
         document.lines.each do |element|
           element.line.each { |line| all << Invoice::InvoiceLine.new(parent: element, element: line, invoice: self) }
         end
         all
      end
    end

    class InvoiceLine
      attr_accessor :invoice

      def initialize(options = {})
        @element = nil
        options.each{ |k, v| instance_variable_set "@#{k.to_s}", v }
      end

      def get(name); @element.send(name) ? @element.send(name).node_value : @element[name]; end
      def set(name, value); @element.send(name).node_value = value; end

      def attribute?(name)
        (@element.send(name) || @element[name]) ? true : false
      end

      def method_missing(method_symbol, *params)
        method_name = method_symbol.to_s
        setter = method_name.to_s.gsub!(/=/,'')
        return super unless attribute?(method_name)
        setter ? set(method_name, params.first) : get(method_name)
      end
    end
  end

end