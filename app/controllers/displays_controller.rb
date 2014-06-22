class DisplaysController < ApplicationController

  def index
    # Is this coming from an Android WebView?
    if request.headers['X-Requested-With'] or params[:mobile] == "1"
      # Redirect outdated applications to Play Store.
      if request.headers['X-Requested-With'] == 'com.aktarer.rpishuttle'
        render :file => "#{Rails.root}/public/mobile_redirect.html", :status => 403, :layout => false
      else
        render :layout => 'mobile_map', :template => 'displays/index_mobile.html.erb'
      end
    else
      @pages = Page.order("name").frontpage
      render :layout => 'full_map'
    end
  end

  # Generate a static KML file, a snapshot of the system.
  # Works well for devices that don't understand network links.
  def static
    @stops = Stop.enabled
    @routes = Route.enabled
    @vehicles = Vehicle.active

    respond_to do |format|
      format.kml
    end
  end

  # Generates a network-link based file, a snapshot of the 
  # routes and stops.  The vehicles will be loaded another way.
  def netlink
    @stops = Stop.enabled
    @routes = Route.enabled
 
    respond_to do |format|
      format.kml # netlink.kml.builder
      format.js { # Manually build some objects to jsonify
        data = {:stops => [], :routes => []}
        @stops.each do |s|
          data[:stops].push(s.serializable_hash(
            :only => [:short_name, :name, :latitude, :longitude], 
            :include => {:routes => 
              {:only => [:id, :name]}
            }
          ))
        end
        @routes.each do |r|
          data[:routes].push(r.serializable_hash(
            :only => [:id, :name, :color, :width],
            :include => {:coords =>
              {:only => [:latitude, :longitude]}
            }
          ))
        end
        render :json => data
      }
    end
  end
  
  # Redirect you to a page that shows a static image of the current vehicle positions.
  def image
    require 'hash_reduce' # This does the hard thinking!
    @vehicles = Vehicle.all
    
    @icons = Hash.new
    @vehicles.each do |v|
      if !v.latest_position.nil?
        icon = v.icon_id || 0
        heading = v.latest_position.heading
        if @icons.has_key?(icon)
          if @icons[icon].has_key?(heading)
            @icons[icon][heading].push(v)
          else
            @icons[icon][heading] = [v]
          end
        else
          @icons[icon] = Hash.new
          @icons[icon][heading] = [v]
        end
      end
    end

    base = "http://maps.google.com/maps/api/staticmap?"
    url = Hash.new
    url['sensor'] = false # We never know where the user is.

    url['size'] = "640x640"
    # Allow the size to be overriden if it is valid
    if !params[:size].blank? && /^\d+x\d+$/.match(params[:size])
      url['size'] = params[:size]
    end

    # Incase the format is important...
    case request.format
      when Mime::PNG
        url['format'] = "png"
      when Mime::JPG
        url['format'] = "jpg"
      when Mime::GIF
        url['format'] = "gif"
    end

    url.each do |key, value|
      base += "&" + key + "=" + value.to_s
    end

    gmax = 5 # Google limits us to 5 custom icons at the moment
    key_count = [gmax, @icons.keys.length].max # If we have > 5 different icons in use, use that value (idk what google will do)

    icons = HashReduce.double_hash_reduce(@icons, key_count) # Perform the crazy reduction

    icons.each do |icon, headings|
      if icon == 0 # For no icon, quickly collect the data without caring about headings
        base += "&markers="
        lat_lngs = []
        headings.each_value do |vehicles|
          vehicles.each do |vehicle|
            lat_lngs.push("#{vehicle.latest_position.latitude},#{vehicle.latest_position.longitude}")
          end
        end
        base += lat_lngs.join("|")
      else # We have to care about the heading....
        headings.each do |heading, vehicles|
          lat_lngs = []
          icon_url = rotate_icon_path(:id => icon, :heading => heading, :format => 'png', :only_path => false)
          base += "&markers=icon:#{icon_url}|"
  
          vehicles.each do |vehicle|
            lat_lngs.push("#{vehicle.latest_position.latitude},#{vehicle.latest_position.longitude}")
          end
          base += lat_lngs.join("|")
        end
      end
    end

    # A trap to help debug
    if !params[:debug].blank?
      render :text => base
    else
      redirect_to base
    end

  end
  
end
