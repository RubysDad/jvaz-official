(($, window, document) ->
  pluginName = 'stellar'
  defaults = 
    scrollProperty: 'scroll'
    positionProperty: 'position'
    horizontalScrolling: true
    verticalScrolling: true
    horizontalOffset: 0
    verticalOffset: 0
    responsive: false
    parallaxBackgrounds: true
    parallaxElements: true
    hideDistantElements: true
    hideElement: ($elem) ->
      $elem.hide()
      return
    showElement: ($elem) ->
      $elem.show()
      return
  scrollProperty = 
    scroll:
      getLeft: ($elem) ->
        $elem.scrollLeft()
      setLeft: ($elem, val) ->
        $elem.scrollLeft val
        return
      getTop: ($elem) ->
        $elem.scrollTop()
      setTop: ($elem, val) ->
        $elem.scrollTop val
        return
    position:
      getLeft: ($elem) ->
        parseInt($elem.css('left'), 10) * -1
      getTop: ($elem) ->
        parseInt($elem.css('top'), 10) * -1
    margin:
      getLeft: ($elem) ->
        parseInt($elem.css('margin-left'), 10) * -1
      getTop: ($elem) ->
        parseInt($elem.css('margin-top'), 10) * -1
    transform:
      getLeft: ($elem) ->
        computedTransform = getComputedStyle($elem[0])[prefixedTransform]
        if computedTransform != 'none' then parseInt(computedTransform.match(/(-?[0-9]+)/g)[4], 10) * -1 else 0
      getTop: ($elem) ->
        computedTransform = getComputedStyle($elem[0])[prefixedTransform]
        if computedTransform != 'none' then parseInt(computedTransform.match(/(-?[0-9]+)/g)[5], 10) * -1 else 0
  positionProperty = 
    position:
      setLeft: ($elem, left) ->
        $elem.css 'left', left
        return
      setTop: ($elem, top) ->
        $elem.css 'top', top
        return
    transform: setPosition: ($elem, left, startingLeft, top, startingTop) ->
      $elem[0].style[prefixedTransform] = 'translate3d(' + left - startingLeft + 'px, ' + top - startingTop + 'px, 0)'
      return
  vendorPrefix = do ->
    prefixes = /^(Moz|Webkit|Khtml|O|ms|Icab)(?=[A-Z])/
    style = $('script')[0].style
    prefix = ''
    prop = undefined
    for prop of style
      `prop = prop`
      if prefixes.test(prop)
        prefix = prop.match(prefixes)[0]
        break
    if 'WebkitOpacity' of style
      prefix = 'Webkit'
    if 'KhtmlOpacity' of style
      prefix = 'Khtml'
    (property) ->
      prefix + (if prefix.length > 0 then property.charAt(0).toUpperCase() + property.slice(1) else property)
  prefixedTransform = vendorPrefix('transform')
  supportsBackgroundPositionXY = $('<div />', style: 'background:#fff').css('background-position-x') != undefined
  setBackgroundPosition = if supportsBackgroundPositionXY then (($elem, x, y) ->
    $elem.css
      'background-position-x': x
      'background-position-y': y
    return
  ) else (($elem, x, y) ->
    $elem.css 'background-position', x + ' ' + y
    return
  )
  getBackgroundPosition = if supportsBackgroundPositionXY then (($elem) ->
    [
      $elem.css('background-position-x')
      $elem.css('background-position-y')
    ]
  ) else (($elem) ->
    $elem.css('background-position').split ' '
  )
  requestAnimFrame = window.requestAnimationFrame or window.webkitRequestAnimationFrame or window.mozRequestAnimationFrame or window.oRequestAnimationFrame or window.msRequestAnimationFrame or (callback) ->
    setTimeout callback, 1000 / 60
    return

  Plugin = (element, options) ->
    @element = element
    @options = $.extend({}, defaults, options)
    @_defaults = defaults
    @_name = pluginName
    @init()
    return

  Plugin.prototype =
    init: ->
      @options.name = pluginName + '_' + Math.floor(Math.random() * 1e9)
      @_defineElements()
      @_defineGetters()
      @_defineSetters()
      @_handleWindowLoadAndResize()
      @_detectViewport()
      @refresh firstLoad: true
      if @options.scrollProperty == 'scroll'
        @_handleScrollEvent()
      else
        @_startAnimationLoop()
      return
    _defineElements: ->
      if @element == document.body
        @element = window
      @$scrollElement = $(@element)
      @$element = if @element == window then $('body') else @$scrollElement
      @$viewportElement = if @options.viewportElement != undefined then $(@options.viewportElement) else if @$scrollElement[0] == window or @options.scrollProperty == 'scroll' then @$scrollElement else @$scrollElement.parent()
      return
    _defineGetters: ->
      self = this
      scrollPropertyAdapter = scrollProperty[self.options.scrollProperty]

      @_getScrollLeft = ->
        scrollPropertyAdapter.getLeft self.$scrollElement

      @_getScrollTop = ->
        scrollPropertyAdapter.getTop self.$scrollElement

      return
    _defineSetters: ->
      self = this
      scrollPropertyAdapter = scrollProperty[self.options.scrollProperty]
      positionPropertyAdapter = positionProperty[self.options.positionProperty]
      setScrollLeft = scrollPropertyAdapter.setLeft
      setScrollTop = scrollPropertyAdapter.setTop
      @_setScrollLeft = if typeof setScrollLeft == 'function' then ((val) ->
        setScrollLeft self.$scrollElement, val
        return
      ) else $.noop
      @_setScrollTop = if typeof setScrollTop == 'function' then ((val) ->
        setScrollTop self.$scrollElement, val
        return
      ) else $.noop
      @_setPosition = positionPropertyAdapter.setPosition or ($elem, left, startingLeft, top, startingTop) ->
        if self.options.horizontalScrolling
          positionPropertyAdapter.setLeft $elem, left, startingLeft
        if self.options.verticalScrolling
          positionPropertyAdapter.setTop $elem, top, startingTop
        return
      return
    _handleWindowLoadAndResize: ->
      self = this
      $window = $(window)
      if self.options.responsive
        $window.bind 'load.' + @name, ->
          self.refresh()
          return
      $window.bind 'resize.' + @name, ->
        self._detectViewport()
        if self.options.responsive
          self.refresh()
        return
      return
    refresh: (options) ->
      self = this
      oldLeft = self._getScrollLeft()
      oldTop = self._getScrollTop()
      if !options or !options.firstLoad
        @_reset()
      @_setScrollLeft 0
      @_setScrollTop 0
      @_setOffsets()
      @_findParticles()
      @_findBackgrounds()
      # Fix for WebKit background rendering bug
      if options and options.firstLoad and /WebKit/.test(navigator.userAgent)
        $(window).load ->
          `var oldLeft`
          `var oldTop`
          oldLeft = self._getScrollLeft()
          oldTop = self._getScrollTop()
          self._setScrollLeft oldLeft + 1
          self._setScrollTop oldTop + 1
          self._setScrollLeft oldLeft
          self._setScrollTop oldTop
          return
      @_setScrollLeft oldLeft
      @_setScrollTop oldTop
      return
    _detectViewport: ->
      viewportOffsets = @$viewportElement.offset()
      hasOffsets = viewportOffsets != null and viewportOffsets != undefined
      @viewportWidth = @$viewportElement.width()
      @viewportHeight = @$viewportElement.height()
      @viewportOffsetTop = if hasOffsets then viewportOffsets.top else 0
      @viewportOffsetLeft = if hasOffsets then viewportOffsets.left else 0
      return
    _findParticles: ->
      self = this
      scrollLeft = @_getScrollLeft()
      scrollTop = @_getScrollTop()
      if @particles != undefined
        i = @particles.length - 1
        while i >= 0
          @particles[i].$element.data 'stellar-elementIsActive', undefined
          i--
      @particles = []
      if !@options.parallaxElements
        return
      @$element.find('[data-stellar-ratio]').each (i) ->
        $this = $(this)
        horizontalOffset = undefined
        verticalOffset = undefined
        positionLeft = undefined
        positionTop = undefined
        marginLeft = undefined
        marginTop = undefined
        $offsetParent = undefined
        offsetLeft = undefined
        offsetTop = undefined
        parentOffsetLeft = 0
        parentOffsetTop = 0
        tempParentOffsetLeft = 0
        tempParentOffsetTop = 0
        # Ensure this element isn't already part of another scrolling element
        if !$this.data('stellar-elementIsActive')
          $this.data 'stellar-elementIsActive', this
        else if $this.data('stellar-elementIsActive') != this
          return
        self.options.showElement $this
        # Save/restore the original top and left CSS values in case we refresh the particles or destroy the instance
        if !$this.data('stellar-startingLeft')
          $this.data 'stellar-startingLeft', $this.css('left')
          $this.data 'stellar-startingTop', $this.css('top')
        else
          $this.css 'left', $this.data('stellar-startingLeft')
          $this.css 'top', $this.data('stellar-startingTop')
        positionLeft = $this.position().left
        positionTop = $this.position().top
        # Catch-all for margin top/left properties (these evaluate to 'auto' in IE7 and IE8)
        marginLeft = if $this.css('margin-left') == 'auto' then 0 else parseInt($this.css('margin-left'), 10)
        marginTop = if $this.css('margin-top') == 'auto' then 0 else parseInt($this.css('margin-top'), 10)
        offsetLeft = $this.offset().left - marginLeft
        offsetTop = $this.offset().top - marginTop
        # Calculate the offset parent
        $this.parents().each ->
          `var $this`
          $this = $(this)
          if $this.data('stellar-offset-parent') == true
            parentOffsetLeft = tempParentOffsetLeft
            parentOffsetTop = tempParentOffsetTop
            $offsetParent = $this
            return false
          else
            tempParentOffsetLeft += $this.position().left
            tempParentOffsetTop += $this.position().top
          return
        # Detect the offsets
        horizontalOffset = if $this.data('stellar-horizontal-offset') != undefined then $this.data('stellar-horizontal-offset') else if $offsetParent != undefined and $offsetParent.data('stellar-horizontal-offset') != undefined then $offsetParent.data('stellar-horizontal-offset') else self.horizontalOffset
        verticalOffset = if $this.data('stellar-vertical-offset') != undefined then $this.data('stellar-vertical-offset') else if $offsetParent != undefined and $offsetParent.data('stellar-vertical-offset') != undefined then $offsetParent.data('stellar-vertical-offset') else self.verticalOffset
        # Add our object to the particles collection
        self.particles.push
          $element: $this
          $offsetParent: $offsetParent
          isFixed: $this.css('position') == 'fixed'
          horizontalOffset: horizontalOffset
          verticalOffset: verticalOffset
          startingPositionLeft: positionLeft
          startingPositionTop: positionTop
          startingOffsetLeft: offsetLeft
          startingOffsetTop: offsetTop
          parentOffsetLeft: parentOffsetLeft
          parentOffsetTop: parentOffsetTop
          stellarRatio: if $this.data('stellar-ratio') != undefined then $this.data('stellar-ratio') else 1
          width: $this.outerWidth(true)
          height: $this.outerHeight(true)
          isHidden: false
        return
      return
    _findBackgrounds: ->
      self = this
      scrollLeft = @_getScrollLeft()
      scrollTop = @_getScrollTop()
      $backgroundElements = undefined
      @backgrounds = []
      if !@options.parallaxBackgrounds
        return
      $backgroundElements = @$element.find('[data-stellar-background-ratio]')
      if @$element.data('stellar-background-ratio')
        $backgroundElements = $backgroundElements.add(@$element)
      $backgroundElements.each ->
        $this = $(this)
        backgroundPosition = getBackgroundPosition($this)
        horizontalOffset = undefined
        verticalOffset = undefined
        positionLeft = undefined
        positionTop = undefined
        marginLeft = undefined
        marginTop = undefined
        offsetLeft = undefined
        offsetTop = undefined
        $offsetParent = undefined
        parentOffsetLeft = 0
        parentOffsetTop = 0
        tempParentOffsetLeft = 0
        tempParentOffsetTop = 0
        # Ensure this element isn't already part of another scrolling element
        if !$this.data('stellar-backgroundIsActive')
          $this.data 'stellar-backgroundIsActive', this
        else if $this.data('stellar-backgroundIsActive') != this
          return
        # Save/restore the original top and left CSS values in case we destroy the instance
        if !$this.data('stellar-backgroundStartingLeft')
          $this.data 'stellar-backgroundStartingLeft', backgroundPosition[0]
          $this.data 'stellar-backgroundStartingTop', backgroundPosition[1]
        else
          setBackgroundPosition $this, $this.data('stellar-backgroundStartingLeft'), $this.data('stellar-backgroundStartingTop')
        # Catch-all for margin top/left properties (these evaluate to 'auto' in IE7 and IE8)
        marginLeft = if $this.css('margin-left') == 'auto' then 0 else parseInt($this.css('margin-left'), 10)
        marginTop = if $this.css('margin-top') == 'auto' then 0 else parseInt($this.css('margin-top'), 10)
        offsetLeft = $this.offset().left - marginLeft - scrollLeft
        offsetTop = $this.offset().top - marginTop - scrollTop
        # Calculate the offset parent
        $this.parents().each ->
          `var $this`
          $this = $(this)
          if $this.data('stellar-offset-parent') == true
            parentOffsetLeft = tempParentOffsetLeft
            parentOffsetTop = tempParentOffsetTop
            $offsetParent = $this
            return false
          else
            tempParentOffsetLeft += $this.position().left
            tempParentOffsetTop += $this.position().top
          return
        # Detect the offsets
        horizontalOffset = if $this.data('stellar-horizontal-offset') != undefined then $this.data('stellar-horizontal-offset') else if $offsetParent != undefined and $offsetParent.data('stellar-horizontal-offset') != undefined then $offsetParent.data('stellar-horizontal-offset') else self.horizontalOffset
        verticalOffset = if $this.data('stellar-vertical-offset') != undefined then $this.data('stellar-vertical-offset') else if $offsetParent != undefined and $offsetParent.data('stellar-vertical-offset') != undefined then $offsetParent.data('stellar-vertical-offset') else self.verticalOffset
        self.backgrounds.push
          $element: $this
          $offsetParent: $offsetParent
          isFixed: $this.css('background-attachment') == 'fixed'
          horizontalOffset: horizontalOffset
          verticalOffset: verticalOffset
          startingValueLeft: backgroundPosition[0]
          startingValueTop: backgroundPosition[1]
          startingBackgroundPositionLeft: if isNaN(parseInt(backgroundPosition[0], 10)) then 0 else parseInt(backgroundPosition[0], 10)
          startingBackgroundPositionTop: if isNaN(parseInt(backgroundPosition[1], 10)) then 0 else parseInt(backgroundPosition[1], 10)
          startingPositionLeft: $this.position().left
          startingPositionTop: $this.position().top
          startingOffsetLeft: offsetLeft
          startingOffsetTop: offsetTop
          parentOffsetLeft: parentOffsetLeft
          parentOffsetTop: parentOffsetTop
          stellarRatio: if $this.data('stellar-background-ratio') == undefined then 1 else $this.data('stellar-background-ratio')
        return
      return
    _reset: ->
      particle = undefined
      startingPositionLeft = undefined
      startingPositionTop = undefined
      background = undefined
      i = undefined
      i = @particles.length - 1
      while i >= 0
        particle = @particles[i]
        startingPositionLeft = particle.$element.data('stellar-startingLeft')
        startingPositionTop = particle.$element.data('stellar-startingTop')
        @_setPosition particle.$element, startingPositionLeft, startingPositionLeft, startingPositionTop, startingPositionTop
        @options.showElement particle.$element
        particle.$element.data('stellar-startingLeft', null).data('stellar-elementIsActive', null).data 'stellar-backgroundIsActive', null
        i--
      i = @backgrounds.length - 1
      while i >= 0
        background = @backgrounds[i]
        background.$element.data('stellar-backgroundStartingLeft', null).data 'stellar-backgroundStartingTop', null
        setBackgroundPosition background.$element, background.startingValueLeft, background.startingValueTop
        i--
      return
    destroy: ->
      @_reset()
      @$scrollElement.unbind('resize.' + @name).unbind 'scroll.' + @name
      @_animationLoop = $.noop
      $(window).unbind('load.' + @name).unbind 'resize.' + @name
      return
    _setOffsets: ->
      self = this
      $window = $(window)
      $window.unbind('resize.horizontal-' + @name).unbind 'resize.vertical-' + @name
      if typeof @options.horizontalOffset == 'function'
        @horizontalOffset = @options.horizontalOffset()
        $window.bind 'resize.horizontal-' + @name, ->
          self.horizontalOffset = self.options.horizontalOffset()
          return
      else
        @horizontalOffset = @options.horizontalOffset
      if typeof @options.verticalOffset == 'function'
        @verticalOffset = @options.verticalOffset()
        $window.bind 'resize.vertical-' + @name, ->
          self.verticalOffset = self.options.verticalOffset()
          return
      else
        @verticalOffset = @options.verticalOffset
      return
    _repositionElements: ->
      scrollLeft = @_getScrollLeft()
      scrollTop = @_getScrollTop()
      horizontalOffset = undefined
      verticalOffset = undefined
      particle = undefined
      fixedRatioOffset = undefined
      background = undefined
      bgLeft = undefined
      bgTop = undefined
      isVisibleVertical = true
      isVisibleHorizontal = true
      newPositionLeft = undefined
      newPositionTop = undefined
      newOffsetLeft = undefined
      newOffsetTop = undefined
      i = undefined
      # First check that the scroll position or container size has changed
      if @currentScrollLeft == scrollLeft and @currentScrollTop == scrollTop and @currentWidth == @viewportWidth and @currentHeight == @viewportHeight
        return
      else
        @currentScrollLeft = scrollLeft
        @currentScrollTop = scrollTop
        @currentWidth = @viewportWidth
        @currentHeight = @viewportHeight
      # Reposition elements
      i = @particles.length - 1
      while i >= 0
        particle = @particles[i]
        fixedRatioOffset = if particle.isFixed then 1 else 0
        # Calculate position, then calculate what the particle's new offset will be (for visibility check)
        if @options.horizontalScrolling
          newPositionLeft = (scrollLeft + particle.horizontalOffset + @viewportOffsetLeft + particle.startingPositionLeft - (particle.startingOffsetLeft) + particle.parentOffsetLeft) * -(particle.stellarRatio + fixedRatioOffset - 1) + particle.startingPositionLeft
          newOffsetLeft = newPositionLeft - (particle.startingPositionLeft) + particle.startingOffsetLeft
        else
          newPositionLeft = particle.startingPositionLeft
          newOffsetLeft = particle.startingOffsetLeft
        if @options.verticalScrolling
          newPositionTop = (scrollTop + particle.verticalOffset + @viewportOffsetTop + particle.startingPositionTop - (particle.startingOffsetTop) + particle.parentOffsetTop) * -(particle.stellarRatio + fixedRatioOffset - 1) + particle.startingPositionTop
          newOffsetTop = newPositionTop - (particle.startingPositionTop) + particle.startingOffsetTop
        else
          newPositionTop = particle.startingPositionTop
          newOffsetTop = particle.startingOffsetTop
        # Check visibility
        if @options.hideDistantElements
          isVisibleHorizontal = !@options.horizontalScrolling or newOffsetLeft + particle.width > (if particle.isFixed then 0 else scrollLeft) and newOffsetLeft < (if particle.isFixed then 0 else scrollLeft) + @viewportWidth + @viewportOffsetLeft
          isVisibleVertical = !@options.verticalScrolling or newOffsetTop + particle.height > (if particle.isFixed then 0 else scrollTop) and newOffsetTop < (if particle.isFixed then 0 else scrollTop) + @viewportHeight + @viewportOffsetTop
        if isVisibleHorizontal and isVisibleVertical
          if particle.isHidden
            @options.showElement particle.$element
            particle.isHidden = false
          @_setPosition particle.$element, newPositionLeft, particle.startingPositionLeft, newPositionTop, particle.startingPositionTop
        else
          if !particle.isHidden
            @options.hideElement particle.$element
            particle.isHidden = true
        i--
      # Reposition backgrounds
      i = @backgrounds.length - 1
      while i >= 0
        background = @backgrounds[i]
        fixedRatioOffset = if background.isFixed then 0 else 1
        bgLeft = if @options.horizontalScrolling then (scrollLeft + background.horizontalOffset - (@viewportOffsetLeft) - (background.startingOffsetLeft) + background.parentOffsetLeft - (background.startingBackgroundPositionLeft)) * (fixedRatioOffset - (background.stellarRatio)) + 'px' else background.startingValueLeft
        bgTop = if @options.verticalScrolling then (scrollTop + background.verticalOffset - (@viewportOffsetTop) - (background.startingOffsetTop) + background.parentOffsetTop - (background.startingBackgroundPositionTop)) * (fixedRatioOffset - (background.stellarRatio)) + 'px' else background.startingValueTop
        setBackgroundPosition background.$element, bgLeft, bgTop
        i--
      return
    _handleScrollEvent: ->
      self = this
      ticking = false

      update = ->
        self._repositionElements()
        ticking = false
        return

      requestTick = ->
        if !ticking
          requestAnimFrame update
          ticking = true
        return

      @$scrollElement.bind 'scroll.' + @name, requestTick
      requestTick()
      return
    _startAnimationLoop: ->
      self = this

      @_animationLoop = ->
        requestAnimFrame self._animationLoop
        self._repositionElements()
        return

      @_animationLoop()
      return

  $.fn[pluginName] = (options) ->
    args = arguments
    if options == undefined or typeof options == 'object'
      return @each(->
        if !$.data(this, 'plugin_' + pluginName)
          $.data this, 'plugin_' + pluginName, new Plugin(this, options)
        return
      )
    else if typeof options == 'string' and options[0] != '_' and options != 'init'
      return @each(->
        instance = $.data(this, 'plugin_' + pluginName)
        if instance instanceof Plugin and typeof instance[options] == 'function'
          instance[options].apply instance, Array::slice.call(args, 1)
        if options == 'destroy'
          $.data this, 'plugin_' + pluginName, null
        return
      )
    return

  $[pluginName] = (options) ->
    $window = $(window)
    $window.stellar.apply $window, Array::slice.call(arguments, 0)

  # Expose the scroll and position property function hashes so they can be extended
  $[pluginName].scrollProperty = scrollProperty
  $[pluginName].positionProperty = positionProperty
  # Expose the plugin class so it can be modified
  window.Stellar = Plugin
  return
) jQuery, this, document