require 'cgi'

module Jekyll
  module UnescapeFilter
    def unescape_html(input)
      return if input.nil?
      str = input.to_s

      # Remove all variants of &shy; (including double escaped ones like &amp;shy;)
      str = str.gsub(/&amp;shy;|&shy;|\u00AD/i, '')
      
      CGI.unescapeHTML(str)
    end
  end
end

Liquid::Template.register_filter(Jekyll::UnescapeFilter)
