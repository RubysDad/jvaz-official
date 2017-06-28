do ->
  ua = navigator.userAgent
  isMobileWebkit = /WebKit/.test(ua) and /Mobile/.test(ua)
  if isMobileWebkit
    $('html').addClass 'mobile'
  $ ->
    iScrollInstance = undefined
    if isMobileWebkit
      iScrollInstance = new iScroll('wrapper')
      $('#scroller').stellar
        scrollProperty: 'transform'
        positionProperty: 'transform'
        horizontalScrolling: false
        verticalOffset: 150
    else
      $.stellar
        horizontalScrolling: false
        verticalOffset: 150
    return
  return