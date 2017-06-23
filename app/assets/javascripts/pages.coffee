$(document).ready ->
  $('#menu-close').click (e) ->
    e.preventDefault()
    $('#sidebar-wrapper').toggleClass 'active'
    return
  # Opens the sidebar menu
  $('#menu-toggle').click (e) ->
    e.preventDefault()
    $('#sidebar-wrapper').toggleClass 'active'
    return
  # Scrolls to the selected menu item on the page
  $ ->
    $('a[href*=\\#]:not([href=\\#])').click ->
      if location.pathname.replace(/^\//, '') == @pathname.replace(/^\//, '') or location.hostname == @hostname
        target = $(@hash)
        target = if target.length then target else $('[name=' + @hash.slice(1) + ']')
        if target.length
          $('html,body').animate { scrollTop: target.offset().top }, 1000
          return false
      return
    return
  return
