require 'liquid'

module Jekyll
  # Helper class to process documents for LLM friendliness
  class LlmMarkdownProcessor
    HEADER_SHIFT_LEVEL = 4

    def self.process_document(doc, site)
      # Skip if it's a file we don't need to process
      full_path = site.in_source_dir(doc.relative_path)
      return unless File.exist?(full_path)

      file_content = File.read(full_path, encoding: "utf-8")
      content_parts = file_content.split(/^---+\s*$/)

      if content_parts.size >= 3
        # Extract the raw markdown body (everything after the front matter)
        raw_markdown = content_parts[2..].join("---").strip

        begin
          # Setup the full site payload context
          site_payload = site.site_payload
          context = Liquid::Context.new(
            [site_payload.merge({ "page" => doc.data })], # Environments
            {},                                            # Outer Scopes
            { site: site, page: doc.data },                # Registers (CRUCIAL!)
            true                                           # Rethrow Errors
          )
          
          template = site.liquid_renderer.file(doc.path).parse(raw_markdown)

          # Render the liquid tags with full access to configuration drops and includes
          rendered_markdown = template.render(context)
        rescue => e
          Jekyll.logger.warn "LlmMarkdownProcessor:", "Could not render Liquid tags in #{doc.relative_path}: #{e.message}"
          rendered_markdown = raw_markdown
        end

        # 1. Convert HTML img to Markdown link
        rendered_markdown.gsub!(/<img\b[^>]*?>/im) do |img_tag|
          src_match = img_tag.match(/\bsrc=["']([^"']+)["']/i)
          src_url = src_match ? src_match[1] : ""

          alt_match = img_tag.match(/\balt=["']([^"']+)["']/i)
          alt_text = alt_match ? alt_match[1] : ""
          
          if src_url.empty?
            ""
          else
            "![#{alt_text}](#{src_url})"
          end
        end

        # 2. Removes HTML tags except <style> and </style> tags
        rendered_markdown.gsub!(/<(?!style\b|\/style\b)\/?[^>]*>/i, "")

        # 3. Hierarchy shift: Dynamically shift all markdown headers down based on the constant
        rendered_markdown.gsub!(/^(#+)(?=\s)/) do |header_match|
          header_match + ("#" * HEADER_SHIFT_LEVEL)
        end

        # 4. Strip all accidental leading spaces before images globally
        rendered_markdown.gsub!(/^[ \t]+(\!\[)/, '\1')

        # Clean up lines that contain nothing but empty whitespace
        rendered_markdown.gsub!(/^[ \t]+$/, '')

        doc.data["raw_md"] = rendered_markdown.strip
      else
        doc.data["raw_md"] = doc.content
      end
    end
  end
end

# Hook into the pre_render stage for BOTH posts and pages.
# This guarantees doc.data['raw_md'] is populated before Jekyll caches or drops the data.
Jekyll::Hooks.register :posts, :pre_render do |post, payload|
  Jekyll::LlmMarkdownProcessor.process_document(post, post.site)
end

Jekyll::Hooks.register :pages, :pre_render do |page, payload|
  # Only process standard pages, skip layout-less or utility files if necessary
  Jekyll::LlmMarkdownProcessor.process_document(page, page.site)
end
