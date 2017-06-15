KEY_ENTER = 13
defaults =
	mapType: 'roadmap'
	defaultLat: 1
	defaultLng: 1
	geolocation: false
	searchBox: false
	autolocate: true
	zoom: 8,
	libraries: 'places',
	key: '',
	language: 'en',
	direction: 'ltr',
	geoCoding: false,
	geoCodingCallBack: null,
	animateMarker: false
markers = {}

AutoForm.addInputType 'map',
	template: 'afMap'
	valueOut: ->
		node = $(@context)

		lat = node.find('.js-lat').val()
		lng = node.find('.js-lng').val()

		if lat?.length > 0 and lng?.length > 0
			lat: lat
			lng: lng
	contextAdjust: (ctx) ->
		ctx.loading = new ReactiveVar(false)
		ctx
	valueConverters:
		string: (value) ->
			if @attr('reverse')
				"#{value.lng},#{value.lat}"
			else
				"#{value.lat},#{value.lng}"
		numberArray: (value) ->
			[value.lng, value.lat]

Template.afMap.created = ->
	@mapReady = new ReactiveVar false
	@options = _.extend {}, defaults, @data.atts

	if typeof google != 'object' || typeof google.maps != 'object'
		GoogleMaps.load(libraries: @options.libraries, key: @options.key, language: @options.language)

	@_stopInterceptValue = false
	@_interceptValue = (ctx) ->
		t = Template.instance()
		if t.mapReady.get() and ctx.value and not t._stopInterceptValue
			location = if typeof ctx.value == 'string' then ctx.value.split ',' else if ctx.value.hasOwnProperty 'lat' then [ctx.value.lat, ctx.value.lng] else [ctx.value[1], ctx.value[0]]
			location = new google.maps.LatLng parseFloat(location[0]), parseFloat(location[1])
			t.setMarker t.map, location, t.options.zoom
			t.map.setCenter location
			t._stopInterceptValue = true
			if isNaN(t.data.marker.position.lat())
				initTemplateAndGoogleMaps.apply t
	@_getMyLocation = (t) ->
		unless navigator.geolocation then return false

		t.data.loading.set true
		navigator.geolocation.getCurrentPosition (position) =>
			location = new google.maps.LatLng position.coords.latitude, position.coords.longitude
			t.setMarker t.map, location, t.options.zoom
			t.data.loading.set false
	@_getDefaultLocation = (t) ->
		unless navigator.geolocation then return false
		
		t.data.loading.set true
		location = new google.maps.LatLng t.options.defaultLat, t.options.defaultLng
		t.map.setCenter location
		t.setMarker t.map, location, t.options.zoom
		t.data.loading.set false

initTemplateAndGoogleMaps = ->
	@data.marker = undefined
	@setMarker = (map, location, zoom=0) =>
		@$('.js-lat').val(location.lat())
		@$('.js-lng').val(location.lng())

		if @data.marker
			@data.marker.setPosition location
			if @data.marker.map != @map
				@data.marker.setMap(@map)
		else if markers[@data.name] != undefined
			@data.marker = markers[@data.name].marker
			@data.marker.setMap(markers[@data.name].map)
			@data.marker.setPosition location
		else
			markerOpts = 
				position: location
				map: @map
			if @options.animateMarker
				markerOpts.animation = google.maps.Animation.DROP
			@data.marker = new google.maps.Marker markerOpts
			markers[@data.name] = {marker: @data.marker, map: @map}

		if zoom > 0
			@map.setZoom zoom

		if @geocoder != undefined && @options.geoCodingCallBack != null
			window[@options.geoCodingCallBack](@, @geocoder, location)

	mapOptions =
		zoom: 0
		mapTypeId: google.maps.MapTypeId[@options.mapType]
		streetViewControl: false

	if @data.atts.googleMap
		_.extend mapOptions, @data.atts.googleMap

	@map = new google.maps.Map @find('.js-map'), mapOptions

	if @data.atts.searchBox
		input = @find('.js-search')

		if @options.direction == 'rtl'
			@map.controls[google.maps.ControlPosition.TOP_RIGHT].push input
		else
			@map.controls[google.maps.ControlPosition.TOP_LEFT].push input
		searchBox = new google.maps.places.SearchBox input

		google.maps.event.addListener searchBox, 'places_changed', =>
			location = searchBox.getPlaces()[0].geometry.location
			@setMarker @map, location, @options.zoom
			@map.setCenter location

		$(input).removeClass('af-map-search-box-hidden')

	if @data.atts.geolocation
		myLocation = @find('.js-locate')
		myLocation.addEventListener 'click', => @._getMyLocation(@)
		if @options.direction == 'rtl'
			@map.controls[google.maps.ControlPosition.TOP_LEFT].push myLocation
		else
			@map.controls[google.maps.ControlPosition.TOP_RIGHT].push myLocation

	if @data.atts.autolocate and navigator.geolocation
		navigator.geolocation.getCurrentPosition (position) =>
			location = new google.maps.LatLng position.coords.latitude, position.coords.longitude
			@setMarker @map, location, @options.zoom
			@map.setCenter location
			if @options.geoCoding
				@geocoder = new google.maps.Geocoder
	else
		@._getDefaultLocation @

	if typeof @data.atts.rendered == 'function'
		@data.atts.rendered @map

	google.maps.event.addListener @map, 'click', (e) =>
		@setMarker @map, e.latLng, @map.zoom

	@$('.js-map').closest('form').on 'reset', =>
		if @data.atts.autolocate
			@._getMyLocation @
		else
			@._getDefaultLocation @

	@mapReady.set true

Template.afMap.onRendered ->
	@autorun =>
		GoogleMaps.loaded() and initTemplateAndGoogleMaps.apply this

Template.afMap.onDestroyed ->
	delete markers[@data.name]

Template.afMap.helpers
	schemaKey: ->
		Template.instance()._interceptValue @
		@atts['data-schema-key']
	width: ->
		if typeof @atts.width == 'string'
			@atts.width
		else if typeof @atts.width == 'number'
			@atts.width + 'px'
		else
			'100%'
	height: ->
		if typeof @atts.height == 'string'
			@atts.height
		else if typeof @atts.height == 'number'
			@atts.height + 'px'
		else
			'200px'
	loading: ->
		@loading.get()

Template.afMap.events
	'click .js-locate': (e) ->
		e.preventDefault()

	'keydown .js-search': (e) ->
		if e.keyCode == KEY_ENTER then e.preventDefault()

