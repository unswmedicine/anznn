$(function() {
    $(document).ready(function(){
        $('.btn-deselect').live('click', function() {
            var radio_groups = $(this).parent('.inputs-list');
            radio_groups.each(function() {
                var radio_btns = $(this).find('input[type="radio"]');
                radio_btns.each(function() {
                    $(this).removeAttr('checked');
                });
            });
            return false;
        });
    });
});