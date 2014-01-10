$(function() {
    $('.btn-cancel').each(
        function() {
            $(this).click(function() {
               $(this).parent().parent().modal('hide');
            });

        }
    );
});

