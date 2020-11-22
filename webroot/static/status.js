var geturl;
geturl = $.ajax({
   type: "GET",
   url: '/stamp',
   success: function () {
     var modified = geturl.getResponseHeader('Last-Modified');
     $("#date").text(modified);
   },
   error: function () {
     $("#date").html("<em>cannot retrive last run information</em>");
   }
 });
