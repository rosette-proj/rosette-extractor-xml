# encoding: UTF-8

require 'nokogiri'
require 'rosette/core'

module Rosette
  module Extractors

    class XmlExtractor < Rosette::Core::StaticExtractor
      def extract_each_from(xml_content)
        if block_given?
          each_entry(xml_content) do |key, meta_key, line_number|
            yield make_phrase(key, meta_key), line_number
          end
        else
          to_enum(__method__, xml_content)
        end
      end

      def supports_line_numbers?
        true
      end

      protected

      def parse(xml_content)
        Nokogiri::XML(xml_content) do |config|
          config.options = Nokogiri::XML::ParseOptions::NONET
        end
      end

      class AndroidExtractor < XmlExtractor
        protected

        def each_entry(xml_content, &block)
          doc = parse(xml_content)
          each_string_entry(doc, &block)
          each_array_entry(doc, &block)
          each_plural_entry(doc, &block)
        end

        def each_string_entry(doc)
          doc.xpath('//string').each do |node|
            yield(
              text_from(node),
              name_from(node),
              line_number_from(node)
            )
          end
        end

        def each_array_entry(doc)
          doc.xpath('//string-array').each do |array|
            prefix = name_from(array)

            array.xpath('item').each_with_index do |item, idx|
              yield(
                text_from(item),
                "#{prefix}.#{idx}",
                line_number_from(item)
              )
            end
          end
        end

        def each_plural_entry(doc)
          doc.xpath('//plurals').each do |plurals|
            prefix = name_from(plurals)

            plurals.xpath('item').each do |item|
              quantity = item.attributes['quantity'].value

              yield(
                text_from(item),
                "#{prefix}.#{quantity}",
                line_number_from(item)
              )
            end
          end
        end

        def text_from(node)
          builder = Nokogiri::XML::Builder.new do |builder|
            builder.root do
              node.children.each do |child|
                serialize(child, builder)
              end
            end
          end

          strip_enclosing_quotes(
            builder.doc.xpath('/root/node()').to_xml
          )
        end

        def serialize(node, builder)
          if node.text?
            builder.text(unescape(node.text))
          else
            builder.send("#{node.name}_", node.attributes) do
              node.children.each do |child|
                serialize(child, builder)
              end
            end
          end
        end

        def name_from(node)
          if attribute = node.attributes['name']
            attribute.value
          end
        end

        def line_number_from(node)
          node.line
        end

        def unescape(text)
          text
            .gsub("\\'", "'")
            .gsub('\\"', '"')
        end

        def strip_enclosing_quotes(text)
          quote = case text[0]
            when "'", '"'
              text[0]
          end

          if quote
            text.gsub(/\A#{quote}(.*)#{quote}\z/) { $1 }
          else
            text
          end
        end
      end
    end

  end
end