module Stache
  module Hamstache
    # A Convienent Base Class for the views. Subclass this for autoloading magic with your templates.
    class View < ::Stache::Mustache::View
      # Redefine where Stache::View templates locate their partials
      def partial(name)
        cache_key = :"#{virtual_path}/#{name}"

        # Try to resolve template from cache
        template_cached = ::Stache.template_cache.read(cache_key, :namespace => :partials, :raw => true)
        curr_template   = template_cached || Stache::Hamstache::CachedTemplate.new(
          Haml::Engine.new(
            begin # Try to resolve the partial template
              template_finder(name, true)
            rescue ActionView::MissingTemplate
              template_finder(name, false)
            end.source
          ).render(helpers)
        )

        # Store the template
        unless template_cached
          ::Stache.template_cache.write(cache_key, curr_template, :namespace => :partials, :raw => true)
        end

        curr_template
      end

    protected

      def template_finder(name, partial)
        if ActionPack::VERSION::MAJOR == 3 && ActionPack::VERSION::MINOR < 2
          lookup_context.find(name, [], partial)
        else # Rails 3.2 and higher
          lookup_context.find(name, [], partial, [], { formats: [:html], handlers: [:hamstache] })
        end
      end

    end
  end
end
