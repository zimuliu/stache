module Stache
  module AssetHelper
    # template_include_tag("widgets/basic_text_api_data")
    # template_include_tag("shared/test_thing")
    def template_include_tag(*sources)
      options = sources.extract_options!
      sources.collect do |source|
        template_finder = lambda do |partial|
          if ActionPack::VERSION::MAJOR == 3 && ActionPack::VERSION::MINOR < 2
            lookup_context.find(source, [], partial)
          else # Rails 3.2 and higher
            lookup_context.find(source, [], partial, [], { formats: [:html], handlers: [Stache.template_engine] })
          end
        end

        template = template_finder.call(true) rescue template_finder.call(false)
        template_id = (Stache.include_path_in_id) ? source.gsub("/", '_') : source.to_s.split("/").last

        source = case Stache.template_engine
        when :hamstache
          template_cache_key = "#{template.identifier.to_s}#{template.updated_at.to_i}#{I18n.locale}"
          template_cached = ::Stache.template_cache.read(template_cache_key, namespace: :template_assets, raw: true)
          if template_cached
            template_cached
          else
            compiled_source = Haml::Engine.new(template.source).render(self)
            ::Stache.template_cache.write(template_cache_key, compiled_source, namespace: :template_assets, raw: true)
            compiled_source
          end
        else
          template.source
        end

        content_tag(:script, source.html_safe, options.reverse_merge(type: Stache.template_mime, id: "#{Stache.id_prefix}#{template_id.dasherize.underscore}"))

      end.join("\n").html_safe
    end

  end
end
