require "stache/mustache/handler"
require 'stache/hamstache/view'

module Stache
  module Hamstache
    # From HAML, thanks a bunch, guys!
    # In Rails 3.1+, template handlers don't inherit from anything. In <= 3.0, they do.
    # To avoid messy logic figuring this out, we just inherit from whatever the ERB handler does.
    class Handler < ::Stache::Mustache::Handler
      # Thanks to hamstache::Rails3 for getting us most of the way home here
      def compile(template)
        #
        # get a custom hamstache, or the default Stache::Hamstache::View
        hamstache_class = hamstache_class_from_template(template)

        # If the class is in the same directory as the template, the source of the template can be the
        # source of the class, and so we need to read the template source from the file system.
        # Matching against `module` may seem a bit hackish, but at worst it provides false positives
        # only for templates containing the word `module`, and reads the template again from the file
        # system.

        template_is_class = template.source.match(/module/) ? true : false
        virtual_path      = template.virtual_path.to_s

        # Caching key
        template_id = "#{template.identifier.to_s}#{template.updated_at.to_i}"

        # Return a string that will be eval'd in the context of the ActionView, ugly, but it works.
        <<-HAMSTACHE
          hamstache = ::#{hamstache_class}.new
          hamstache.view = self

          hamstache.virtual_path = '#{virtual_path}'
          hamstache[:yield] = content_for(:layout)
          hamstache.context.push(local_assigns)
          variables = controller.instance_variables
          variables.delete(:@template)
          if controller.class.respond_to?(:protected_instance_variables)
            variables -= controller.class.protected_instance_variables.to_a
          end

          variables.each do |name|
            hamstache.instance_variable_set(name, controller.instance_variable_get(name))
          end

          # Add view instance variables also so RSpec view spec assigns will work
          (instance_variable_names - variables).each do |name|
            hamstache.instance_variable_set(name, instance_variable_get(name))
          end

          # Declaring an +attr_reader+ for each instance variable in the
          # Stache::hamstache::View subclass makes them available to your templates.
          hamstache.singleton_class.class_eval do
            attr_reader *variables.map { |name| name.to_s.sub(/^@/, '').to_sym }
          end

          # Try to get template from cache, otherwise use template source
          template_cached = ::Stache.template_cache.read(:'#{template_id}', :namespace => :templates, :raw => true)
          hamstache.template = template_cached || Stache::Hamstache::CachedTemplate.new(
            Haml::Engine.new(
              if #{template_is_class}
                template_name = "#{virtual_path}"
                file = Dir.glob(File.join(::Stache.template_base_path, template_name + "\.*" + hamstache.template_extension)).first
                File.read(file)
              else
                '#{template.source.gsub(/'/, "\\\\'")}'
              end
            ).render(hamstache.helpers)
          )

          # Render - this will also compile the template
          compiled = hamstache.render.html_safe

          # Store the now compiled template
          unless template_cached
            ::Stache.template_cache.write(:'#{template_id}', hamstache.template, :namespace => :templates, :raw => true)
          end

          compiled
        HAMSTACHE
      end

      # suss out a constant name for the given template
      def hamstache_class_from_template(template)
        # If we don't have a source template to render, return an abstract view class.
        # This is normally used with rspec-rails. You probably never want to normally
        # render a bare Stache::View
        if template.source.empty?
          return Stache::Hamstache::View
        end

        const_name = ActiveSupport::Inflector.camelize(ActiveSupport::Inflector.underscore(template.virtual_path.to_s))
        const_name = "#{Stache.wrapper_module_name}::#{const_name}" if Stache.wrapper_module_name
        begin
          const_name.constantize
        rescue NameError, LoadError => e
          # Only rescue NameError/LoadError concerning our hamstache_class
          e_const_name = e.message.match(/ ([^ ]*)$/)[1]
          if const_name.match(/#{e_const_name}(::|$)/)
            Stache::Hamstache::View
          else
            raise e
          end
        end
      end

    end
  end
end
