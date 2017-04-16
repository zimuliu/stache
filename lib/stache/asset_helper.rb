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
          Haml::Engine.new(template.source).render(self)
        else
          template.source
        end

        content_tag(:script, source.html_safe, options.reverse_merge(type: Stache.template_mime, id: "#{Stache.id_prefix}#{template_id.dasherize.underscore}"))

      end.join("\n").html_safe
    end

  end
end
