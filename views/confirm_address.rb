<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="referrer" content="origin">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Page de vote personnelle de <%= citoyen['email']%>">
    <meta name="author" content="LaPrimaire.org">
    <title>Page de vote personnelle de <%= citoyen['email']%> - LaPrimaire.org"</title>
    <link rel="icon" type="image/png" href="/assets/images/favicon.png" />
    <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"> 
    <link rel="stylesheet" href="https://s3.eu-central-1.amazonaws.com/laprimaire/styles/application-cbbc745bd85.css">
    <link rel="canonical" href="https://laprimaire.org/citoyen/vote/<%= citoyen['url_key'] %>">
    <!--[if lt IE 9]>
        <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
        <script src="https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"></script>
    <![endif]-->
<style>
ul.social_buttons > li{
	display: inline-block;
	margin-bottom: 5px;
}

.intro-heading span {
	color: #d91d1c;
	font-weight:bold;
}
.intro-heading {
	font-size: 24px !important;
	color: #527bdd;
}
.intro-lead-in {
	font-size: 16px !important;
	line-height: 20px !important;
}
.photo {
	max-width: 230px;
	margin:0 auto;
	height: 100%;
	max-height: 310px;
	background-position: center center;
	background-repeat: no-repeat;
	overflow: hidden;
}
.hero-feature h3 {
	font-size: 22px;
	margin-top: 10px;
}
.hero-feature h3 span { color: #d91d1c; font-weight: bold; }
.hero-feature p { font-size: 13px; }
.hero-feature img { height: 300px; }
.photo img {
	min-height: 100%;
	min-width: 100%;
	/* IE 8 */
	-ms-filter: "progid:DXImageTransform.Microsoft.Alpha(Opacity=0)";
	/* IE 5-7 */
	filter: alpha(opacity=0);
	/* modern browsers */
	opacity: 0;
}
.hero-feature .blue:hover { background-color:#d91d1c; border-color:red;}
.caption h3 { text-align:center; }
.caption { text-align:justify; }
@media (min-width:980px) {
	.modal-dialog {width:820px;}
	.intro-text {
		padding-top:15px !important;
		padding-bottom:0px !important;
	}
}
.btn.red:hover {
	border-color:#fec503;
	background-color:#fec503;
}
.btn.candidat {
	font-size:13px;
	padding:2px 8px;
}
.thumbnail.pending {
	border:0px;
	background-color:#ffdab9;
}
.thumbnail.absent {
	border:0px;
	background-color:#ffe4e1;
}
.thumbnail.error {
	border:0px;
	background-color:#ffcccc;
}
.thumbnail.success {
	border:0px;
	background-color:#ccffcc;
}
#no-missing-vote {
	font-weight:bold;
	font-size: 20px;
	color:#70cc70;
}
#nb-missing-votes {
	font-weight:bold;
	font-size: 20px;
	color:#d91d1c;
}
.nohover:hover {
	background:none !important;
}
.fa-stack-2x {
	font-size: 42px;
	padding:5px;
}
.fa-stack-1x {
	font-size: 24px;
	top: -2px;
}
.fa-stack.bleu { 
	color:#527bdd;
	line-height:10px;
	height:12px;
}
.fa-stack.rouge { color:#d91d1c; }
.row {
	margin-right:0px;
	margin-left:0px;
}
.soutien {
	height:80px !important;
	width:80px !important;
	border:4px solid #527bdd;
	position:absolute;
	bottom:-5px;
	left:10px;
}
.soutien.deux { left:80px; }
.soutien.trois { left:150px; }
</style>
</head>


<!-- Header -->
<body class="index" style="padding-bottom:0px;">
<div id="fb-root"></div>
    <!-- Navigation -->
    <nav class="navbar navbar-default" style="margin-bottom:0px;">
        <div class="container">
            <!-- Brand and toggle get grouped for better mobile display -->
            <div class="navbar-header">
                <button type="button" class="navbar-toggle" data-toggle="collapse" data-target="#bs-example-navbar-collapse-1">
                    <span class="sr-only">Changer la navigation</span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                </button>
		<a class="navbar-brand" href="/"><img src="https://s3.eu-central-1.amazonaws.com/laprimaire/laprimaire-185x60.jpg" width="185" height="60" srcset="https://s3.eu-central-1.amazonaws.com/laprimaire/laprimaire-185x60.jpg 1x, /assets/images/logos/laprimaire-370x120.png 2x" alt="logo LaPrimaire.org"></a>
            </div>

	<% unless defined?(no_menu) then %>
            <!-- Collect the nav links, forms, and other content for toggling -->
            <div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
                <ul class="nav navbar-nav navbar-right">
                    <li class="hidden">
                        <a href="#page-top"></a>
                    </li>
		    <li>
			    <a class="nohover" style="color:#d91d1c;"><%= citoyen['email'] %></a>
                    </li>
		    <li class="dropdown">
			<a tabindex="0" data-toggle="dropdown">
				La Primaire<span class="caret"></span>
			</a>
			<ul class="dropdown-menu">
				<li><a tabindex="0" href="/qualifies/">Les candidats qualifiés</a></li>
				<li><a tabindex="0" href="/candidats/">Les candidats déclarés</a></li>
				<li><a tabindex="0" href="/citoyens/">Les citoyens plébiscités</a></li>
				<li class="divider"></li>
				<li><a tabindex="0" href="/inscription-candidat/">Être candidat(e)</a></li>
				<li><a tabindex="0" href="/charte/">Charte du candidat</a></li>
				<li class="divider"></li>
				<li><a tabindex="0" href="/manifeste/">Manifeste</a></li>
				<li><a tabindex="0" href="/deroulement/">Déroulement</a></li>
				<li><a tabindex="0" href="/calendrier/">Evènements</a></li>
				<li><a tabindex="0" href="/actus/">Blog</a></li>
				<li><a tabindex="0" href="/presse/">Presse</a></li>
				<li><a tabindex="0" href="/legal/">Mentions légales</a></li>
			</ul>
		    </li>
		   <!-- <li class="dropdown">
			<a tabindex="0" data-toggle="dropdown">
				L'association<span class="caret"></span>
			</a>
			<ul class="dropdown-menu">
				<li><a tabindex="0" href="/transparence/">Transparence</a></li>
				<li><a tabindex="0" href="/equipe/">L'équipe</a></li>
				<li><a tabindex="0" href="/contact/">Nous contacter</a></li>
				<li class="divider"></li>
				<li><a tabindex="0" href="/statuts/">Statuts</a></li>
				<li><a tabindex="0" href="/reglement/">Règlement Intérieur</a></li>
				<li><a tabindex="0" href="/legal/">Mentions légales</a></li>
			</ul>
		    </li>-->
		    <li class="active">
			    <a tabindex="0" href="/financer/" class="donate-link" style="cursor:pointer;background-color:#527bdd;">Faire un don</a>
                    </li>
                </ul>
            </div>
            <!-- /.navbar-collapse -->
    <% end %>
        </div>
        <!-- /.container-fluid -->
    </nav>

    <header>
    <div id="header_overlay" class="white" style="border-bottom: 2px solid #527bdd;padding-top:0px;padding-bottom:20px;">
	    <div class="container">
		    <div class="row" style="padding-top:10px;margin-left:0px;margin-right:0px;">
			    <div class="thumbnail" style="margin-bottom:5px;padding:20px;">
				    <div class="row">
					    <div id="wufoo-q4tpsf91qeatbf">
					    Merci de remplir <a href="https://democratech.wufoo.com/forms/q4tpsf91qeatbf">ce formulaire</a>.
					    </div>
<script type="text/javascript">var q4tpsf91qeatbf;(function(d, t) {
var s = d.createElement(t), options = {
'userName':'democratech',
'formHash':'q4tpsf91qeatbf',
'autoResize':true,
'height':'588',
'async':true,
'host':'wufoo.com',
'defaultValues':'field8=<%= citoyen['firstname'] %>&field9=<%= citoyen['lastname'] %>&field3=<%= citoyen['city'] %>&field5=<%= citoyen['zipcode'] %>&field6=<%= citoyen['country'] %>&field7=<%= citoyen['email'] %>',
'header':'hide',
'ssl':true};
s.src = ('https:' == d.location.protocol ? 'https://' : 'http://') + 'www.wufoo.com/scripts/embed/form.js';
s.onload = s.onreadystatechange = function() {
var rs = this.readyState; if (rs) if (rs != 'complete') if (rs != 'loaded') return;
try { q4tpsf91qeatbf = new WufooForm();q4tpsf91qeatbf.initialize(options);q4tpsf91qeatbf.display(); } catch (e) {}};
var scr = d.getElementsByTagName(t)[0], par = scr.parentNode; par.insertBefore(s, scr);
})(document, 'script');</script>

				    </div>
			    </div>
		    </div>
	    </div>
    </div>
    </header>

    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous"></script>
    <script>
/* google analytics */
(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
 (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
 m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
 })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
ga('create', 'UA-60977053-1', 'auto');
ga('send', 'pageview');

$(document).ready(function() {
});
    </script>
  </body>
</html>
