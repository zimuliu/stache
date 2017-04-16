require "stache/hamstache/handler"
require "stache/hamstache/layout"
require "stache/hamstache/cached_template"
require "stache/hamstache/faster_context"

module Stache
  module Hamstache; end
end

ActionView::Template.register_template_handler :rb, Stache::Hamstache::Handler
ActionView::Template.register_template_handler :hamstache, Stache::Hamstache::Handler
