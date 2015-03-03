$(function() {
  $('.hiddenmulti').hide();

  $('.add_multi_link').each(function(){
    var $button = $(this);
    $button.on('click', function(){
      console.log($button)
      var $parent_div = $button.parent();
      var data = $parent_div.data();
      data['groupNumber'] += 1;
      //show the next group of answers for the multi question
      $parent_div.parent().find('div[data-group-number="' + data['groupNumber'] + '"]').show();
      $button.hide();
      return false;
    });
  });

});