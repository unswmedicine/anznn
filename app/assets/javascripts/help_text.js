// help_text.js

!function($){
  $(document).ready(function(){

    var $field_trigger = $('.field_trigger');
    var $field_info = $('#field_info');
    var $field_title = $('#field_title');
    var initial_text = $field_info.text();

    $field_trigger.focus(function(){
      var guide_for_use = $(this).data('guide');
      var qn_name = $(this).data('name');
      var description = $(this).data('description');

      var formatted = $('<div><h3>Definition</h3><p class="desc-body"><h3>Guide For Use</h3><p class="guide-body"> </div>');
      formatted.find('.desc-body').text(description);
      formatted.find('.guide-body').text(guide_for_use);
      $field_info.html(formatted);
      $field_title.text(qn_name);

    });

    $field_trigger.blur(function(){
      $field_info.text(initial_text);
      $field_title.text("Field Information");
    });

  });
}(jQuery);
