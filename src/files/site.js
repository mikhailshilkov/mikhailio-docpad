(function() {
  var halfSize, htmlEncode;

  htmlEncode = function(value) {
    return $('<div/>').text(value).html();
  };

  halfSize = function(img) {
    var el, h, w;
    el = $(img);
    if (el.height() === 0) {
      console.log('image h/w not available yet, waiting to load');
      setTimeout(function() {
        return halfSize(img);
      }, 500);
      return null;
    } else {
      console.log('image loaded: ' + el.attr('src'));
      h = el.height();
      w = el.width();
      el.height(h / 2.0);
      el.width(w / 2.0);
      return null;
    }
  };

  $(function() {
    $('.post img').each(function() {
      var $el;
      $el = $(this);
      return $el.addClass('img-responsive');
    });
    $('img').each(function() {
      var re;
      re = /.*@2x\..+/;
      if (re.test($(this).attr('src'))) {
        console.log('Found HiDPI Image: ' + $(this).attr('src'));
        halfSize(this);
        return null;
      }
    });
    return $('pre code').each(function(index, element) {
      var $code, classes, e, fixedClass, origClass, _i, _len, _ref;
      $code = $(this);
      classes = (_ref = $code.attr('class')) != null ? _ref.split(' ') : void 0;
      if (classes != null) {
        for (_i = 0, _len = classes.length; _i < _len; _i++) {
          origClass = classes[_i];
          fixedClass = origClass.replace(/^lang-/, 'language-');
          if (fixedClass !== origClass) {
            $code.removeClass(origClass).addClass(fixedClass);
          }
        }
      }
      try {
        return hljs.highlightBlock(element);
      } catch (_error) {
        e = _error;
      }
    });
  });

}).call(this);
