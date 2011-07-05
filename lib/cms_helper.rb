class CmsHelper

  def default_content
    cmsify
  end

  def cmsify(opts={})
    path = opts[:path] || default_path
    field = opts[:field] || "body"
    value = @contents.nil? ? '' : @contents.first.send(field)
    if current_user and current_user.has_role? "admin"
      if @contents.nil?
        # TODO : allow for templating of cms links
        value = "&nbsp;&nbsp;#{link_to '[add text]', url(:admin, :new, :path => opts[:path])}"
      else
        value += "&nbsp;&nbsp;#{link_to '[edit]', url(:content, :id => @contents.first.to_param)}"
      end
    end
    value
  end

  # Returns the default key for the current request, this will be
  # request.route.path if present otherwise request.path
  #
  def default_path
    raise "Unable to access current request." unless self.respond_to? 'request'

    if request.route.class == HttpRouter::Route
      request.route.path
    else
      request.path_info
    end
  end

end
