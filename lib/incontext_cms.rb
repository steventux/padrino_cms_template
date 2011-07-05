module IncontextCms

  # Returns the default key for this request, this will be the request.route.path
  # if present otherwise the request.path
  #
  def default_key
    raise "Unable to access current request." unless self.respond_to? 'request'

    if request.route.class == HttpRouter::Route
      request.route.path
    else
      request.path_info
    end
  end

  def incontext_content(opts={})
    opts[:content_key] = default_key if opts[:content_key].nil?
    opts[:content_field] = 'body' if opts[:content_field].nil?
    content = ContextualContent.where(:content_key => opts[:content_key]).first
    content.nil? ? "" : content.send(opts[:content_field])
  end

end
