var geturl;
geturl = $.ajax({
   type: "GET",
   url: 'https://udd-mirror.debian.net/stamp',
   success: function () {
     var modified = geturl.getResponseHeader('Last-Modified');
     $("#date").text(modified);
   },
   error: function () {
     $("#date").html("<em>cannot retrive last run information</em>");
   }
 });
