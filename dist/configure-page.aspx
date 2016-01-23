<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Custom Actions Configuration</title>
    <script src="//ajax.aspnetcdn.com/ajax/4.0/1/MicrosoftAjax.js" type="text/javascript"></script>
    <script src="//ajax.aspnetcdn.com/ajax/jQuery/jquery-1.11.3.min.js" type="text/javascript"></script>
    <script type="text/javascript">
        "use strict";

        /*
         * Copyright - John Liu @ SharePoint Gurus sharepointgurus.net johnliu.net
         * You are not allowed to remove this header, but you can update the page as you see fit :-)
         */       
        (function ($, spg) {

            var hostweburl;
            var srcurl;
            var srcsequence;

            //load the SharePoint resources
            $(document).ready(function () {
                // get src of script we want to install/uninstall
                srcurl = ($.getUrlVar("src") ? decodeURIComponent($.getUrlVar("src")) : 0) || "hello.js";
                srcsequence = 1000;

                $("#scriptlink-name").val(srcurl);
                $("#scriptlink-sequence").val(srcsequence);

                findHostWebUrl(document.location.pathname).then(function (url) {
                    hostweburl = url;

                    // The SharePoint js files URL are in the form:
                    // web_url/_layouts/15/resource
                    var scriptbase = hostweburl + "/_layouts/15/";

                    // Load the js file and continue to the
                    // success handler
                    $.getScript(scriptbase + "sp.runtime.js");
                    $.when(
                        $.getScript(scriptbase + "sp.js")
                    ).done(function(){
                        // attach executeQueryPromise when SP.ClientContext is loaded
                        SP.ClientContext.prototype.executeQueryPromise = function() {
                            var deferred = $.Deferred();
                            this.executeQueryAsync(function(){ deferred.resolve(arguments); }, function(){ deferred.reject(arguments); });
                            return deferred.promise();
                        };                        
                    });
                    $.when(
                        $.getScript(scriptbase + "SP.UI.Controls.js")
                        // load SPChromeControl when SP.UI.Controls is loaded
                    ).done(function(){
                        // The Help, Account and Contact pages receive the
                        //   same query string parameters as the main page
                        var options = {
                            "appIconUrl": hostweburl + "/_layouts/15/IMAGES/LINKS.GIF",
                            "appTitle": "Custom Actions Configuration",
                            "siteUrl": hostweburl,
                            // The onCssLoaded event allows you to
                            // specify a callback to execute when the
                            // chrome resources have been loaded.
                            "onCssLoaded": "window.spg.chromeLoaded()" 
                        };
        
                        var nav = new SP.UI.Controls.Navigation("chrome_ctrl_placeholder", options);
                        nav.setVisible(true);                        
                    });

                    // read custom actions and set up button clicks
                    spg.listUserCustomActions();
                    $("button#install-site-user-custom-action").click(function(){spg.installUserCustomAction("site");});
                    $("button#uninstall-site-user-custom-action").click(function(){spg.uninstallUserCustomAction("site");});
                    $("button#install-web-user-custom-action").click(function(){spg.installUserCustomAction("web");});
                    $("button#uninstall-web-user-custom-action").click(function(){spg.uninstallUserCustomAction("web");});

                });
            });

            function findHostWebUrl(url) {
                // trying to find the nearest CurrentWeb with a bit of recursive promise fun
                var defer = $.Deferred();

                url = url.substring(0, url.lastIndexOf("/"))

                var p = $.ajax({
                    url: url + "/_api/web",
                    dataType: "json",
                    contentType: 'application/json',
                    headers: { "Accept": "application/json; odata=verbose" },
                    method: "GET",
                    cache: false
                });
                p.done(function (response) {
                    defer.resolve(response.d.ServerRelativeUrl);
                });
                p.fail(function () {

                    if (!url) {
                        defer.reject();
                        return;
                    }
                    // hmm not a web, go higher
                    var p1 = findHostWebUrl(url);
                    p1.then(defer.resolve, defer.reject);
                });

                return defer.promise();
            }

            spg.chromeLoaded = function() {
                // Callback for the onCssLoaded event defined
                // in the options object of the chrome control
                // When the page has loaded the required
                // resources for the chrome control,
                // display the page body.
                $("body").show();
            };

            $.extend({
                getUrlVars: function () {
                    var vars = [], hash;
                    var hashes = window.location.search.slice(window.location.search.indexOf('?') + 1).split('&');
                    for (var i = 0; i < hashes.length; i++) {
                        hash = hashes[i].split('=');
                        vars.push(hash[0]);
                        vars[hash[0]] = hash[1];
                    }
                    return vars;
                },
                getUrlVar: function (name) {
                    return $.getUrlVars()[name];
                }
            });
            
            // refresh both site and web custom actions
            spg.listUserCustomActions = function() {
                function listUserCustomAction(siteOrWeb) {
                    
                    siteOrWeb = (siteOrWeb=="site"? "site":"web");
    
                    var p1 = $.ajax({
                        url: hostweburl + "/_api/"+siteOrWeb+"/userCustomActions?$orderby=Sequence",
                        dataType: "json",
                        contentType: 'application/json',
                        headers: { "Accept": "application/json; odata=verbose" },
                        method: "GET",
                        cache: false
                    });
    
                    p1.then(function (response) {
    
                        $("ul#"+siteOrWeb+"-user-custom-actions").empty();
    
                        $.each(response.d.results, function (i, result) {
                            $("ul#"+siteOrWeb+"-user-custom-actions").append(
                                "<li>" +
                                    " [" + result.Location + "] " +
                                    (result.Title || result.Name || "") +
                                    " ScriptSrc=" + result.ScriptSrc +
                                    " Sequence=" + result.Sequence +
                                "</li>"
                            );
                        });
    
                    });
                    return p1;
                }

                return $.when(
                    listUserCustomAction("site"), 
                    listUserCustomAction("web")
                );                
            };

            // install site or web custom action
            spg.installUserCustomAction = function(siteOrWeb) {

                var webContext = SP.ClientContext.get_current();
                var userCustomActions;
                if (siteOrWeb == "site") {
                    userCustomActions = webContext.get_site().get_userCustomActions();
                }
                else {
                    userCustomActions = webContext.get_web().get_userCustomActions();
                }
                webContext.load(userCustomActions);

                srcurl = $("#scriptlink-name").val();
                srcsequence = parseInt($("#scriptlink-sequence").val()) || 1000;

                var action = userCustomActions.add();

                action.set_location("ScriptLink");
                action.set_title(srcurl);
                action.set_scriptSrc("~sitecollection/SiteAssets/" + srcurl);
                action.set_sequence(srcsequence);
                action.update();

                webContext.load(action);
                return webContext.executeQueryPromise().pipe(function () {
                    return spg.listUserCustomActions();
                });

            };

            // uninstall site or web custom action
            spg.uninstallUserCustomAction = function(siteOrWeb) {

                var webContext = SP.ClientContext.get_current();
                var userCustomActions = webContext.get_site().get_userCustomActions();

                if (siteOrWeb == "site") {
                    userCustomActions = webContext.get_site().get_userCustomActions();
                }
                else {
                    userCustomActions = webContext.get_web().get_userCustomActions();
                }
                webContext.load(userCustomActions);

                srcurl = $("#scriptlink-name").val();
                
                var p1 = webContext.executeQueryPromise();
                var p2 = p1.pipe(function () {

                    var i = 0, count = userCustomActions.get_count(), action = null;
                    for (i = count - 1; i >= 0; i--) {
                        action = userCustomActions.get_item(i);
                        if (action.get_scriptSrc() == "~sitecollection/SiteAssets/" + srcurl) {
                            action.deleteObject();
                        }
                    }
                    return webContext.executeQueryPromise().pipe(function () {
                        return spg.listUserCustomActions();
                    });

                });

                return p2;
            };

        })(jQuery, window.spg = window.spg || {});
    </script>
    <style type="text/css">
        button { width: 150px; margin-bottom: 5px; }        
    </style>
</head>
<body style="display: none">

    <!-- Chrome control placeholder -->
    <div id="chrome_ctrl_placeholder"></div>
    <!-- The chrome control also makes the SharePoint
          Website style sheet available to your page. -->
    <div id="MainContent" style="padding-left:20px;">
        <h1 class="ms-accentText">User Custom Actions Configuration</h1>
        This page lists the current user custom actions configured for the current site and site collection.
        <br />
        <br />

        <h2 class="ms-accentText">Site Collection User Custom Actions</h2>        
        <ul id="site-user-custom-actions">            
        </ul>

        <br />

        <h2 class="ms-accentText">Site User Custom Actions</h2>
        <ul id="web-user-custom-actions">            
        </ul>

        <br />

        <h2 class="ms-accentText">Install User Custom Action</h2>

        <br />

        <div style="float:left; height:100px;">
            <input type="text" id="scriptlink-name" />
            <input type="number" id="scriptlink-sequence" value="1000" />
        </div>
        <div style="float:left;">
            <button id="install-site-user-custom-action" type="button">Install Site Collection</button>
            <button id="uninstall-site-user-custom-action" type="button">Uninstall Site Collection</button>
            
            <br />

            <button id="install-web-user-custom-action" type="button">Install Current Web</button>
            <button id="uninstall-web-user-custom-action" type="button">Uninstall Current Web</button>            
        </div>

        <br />
        <br />

    </div>


</body>
</html>