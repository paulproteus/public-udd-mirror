var geturl;
geturl = $.ajax({
   type: "HEAD",
   url: '/logs/stamp.txt',
   success: function () {
     var modified = geturl.getResponseHeader('Last-Modified');
     $("#date").text(modified);
   },
   error: function () {
     $("#date").html("<em>cannot retrive last run information</em>");
   }
 });
