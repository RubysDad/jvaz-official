ready = ->
  Typed.new '.element',
    strings: [
      'We are not selling houses.'
      'We are selling Happiness!'
    ]
    typeSpeed: 20,
    loop: true,
    startDelay: 0
  return  
  
$(document).ready ready