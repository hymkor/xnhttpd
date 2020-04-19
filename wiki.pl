#!/usr/bin/perl

BEGIN{
    eval{ require 'strict.pm';   }; strict  ->import() unless $@;
    eval{ require 'warnings.pm'; }; warnings->import() unless $@;
}

$::version  = 'based on wifky-1.5.13_1';
$::PROTOCOL = '(?:s?https?|ftp)';
$::RXURL    = '(?:s?https?|ftp)://[-\\w.!~*\'();/?:@&=+$,%#]+' ;
$::charset  = 'UTF-8';
%::form     = %::forms = ();
$::me       = $::postme = $ENV{SCRIPT_NAME} || (split(/[\\\/]/,$0))[-1];
$::print    = ' 'x 10000; $::print = '';
%::config   = ( crypt => '' , sitename => 'markdowned wifky!' );
%::flag     = ();
%::cnt      = ();

my $messages = '';

if( $0 eq __FILE__ ){
    binmode(STDOUT);
    binmode(STDIN);

    eval{
        local $SIG{ALRM} = sub { die("Time out"); };
        local $SIG{__WARN__} = local $SIG{__DIE__} = sub {
            return if ( caller(0) )[1] =~ /\.pm$/;
            my $msg=join(' ',@_);
            if( $msg =~ /^!(.*)!/ ){
                $messages .= '<div>'.&enc($1)."</div>\n" ;
            }else{
                $messages .= '<div>'.&enc($msg)."</div>\n" ;
                my $i=0;
                while( my (undef,$fn,$lno,$subnm)=caller($i++) ){
                    $messages .= sprintf("<div> &nbsp; on %s at %s line %d.</div>\n" ,
                                &enc($subnm),&enc($fn),$lno );
                }
            }
        };
        eval{ alarm 60; };

        &read_form;
        &chdir_and_code;
        foreach my $pl (sort map(/^([-\w\.]+\.plg)$/ ? $1 : (),&etcfiles) ){
            do "./$pl"; die($@) if $@;
        }
        &load_config;
        &init_globals;
        foreach my $pl (sort map(/^([-\w\.]+\.pl)$/ ? $1 : (),&etcfiles) ){
            do "./$pl"; die($@) if $@;
        }

        (my $xdir = __FILE__) =~ s|^.*?(\w+)\.\w+((\.\w+)*)$|../$1.s$2/.|;
        local *DIR;
        if( -d $xdir && opendir(DIR,$xdir) ){
            foreach my $pl (sort map{ /^([-\w\.]+\.pl)$/ ? $1 : () }
                            readdir(DIR) )
            {
                do "$xdir/$pl"; die($@) if $@;
            }
            close(DIR);
        }

        if( $::form{a} ){
            ($::action_plugin{ $::form{a} } || \&action_not_found)->();
        }elsif( $::form{p} ){ # page view
            if( $::form{f} ){ # output attachment
                &action_cat();
            }else{ # output page itself.
                &action_view($::form{p});
            }
        }else{
            &action_default();
        }

        &flush;
        eval{ alarm 0; };
    };
    if( $@ ){
        print $_,"\r\n" for @::http_header;
        print "Content-Type: text/html;\r\n" unless grep(/^Content-Type:/i,@::http_header);
        print "\r\n<html><body>\n",&errmsg($@);
        print $messages if $@ !~ /^!/;
        print "</body></html>\n";
    }
    exit(0);
}

sub action_default{
    if( &object_exists($::config{FrontPage}) ){
        &action_view($::config{FrontPage});
    }else{
        &do_index('recent','rindex','-l');
    }
}

sub chdir_and_code{
    (my $udir = __FILE__ ) =~ s/\.\w+((\.\w+)*)$/.d$1/;
    if( chdir $udir ){
        return;
    }
    mkdir($udir,0755);
    unless( chdir $udir ){
        die("can not access $udir");
    }
}

sub init_globals{
    if( &is('locallink') ){
        $::PROTOCOL = '(?:s?https?|ftp|file)';
        $::RXURL    = '(?:s?https?|ftp|file)://[-\\w.!~*\'();/?:@&=+$,%#]+';
    }

    $ENV{TZ} = $::config{TZ} if $::config{TZ};

    $::target = ( $::config{target}
                ? sprintf(' target="%s"',$::config{target}) : '' );
    $::config{CSS} ||= '.CSS';
    $::config{FrontPage} ||= 'FrontPage';
    ( $::session_cookie = ( split(/[\\\/]/,$0) )[-1] ) =~ s/\.\w+$/_session/;
    $::remote_addr = ($::config{ignore_addr} ? 'NOIP' : ($ENV{REMOTE_ADDR}||'NOIP'));

    %::inline_plugin = (
        'menubar'  => \&plugin_menubar ,
        'nomenubar'=> sub{ $::flag{menubar_printed}=1;'' } ,
        'pagename' => \&plugin_pagename ,
        'recent'   =>
            sub{ '<ul>'.&ls('-r','-t',map("-$_",@_[1..$#_])) . '</ul>' } ,
        'search'   => \&plugin_search ,
        'fn'       => \&plugin_footnote ,
        'ls'       => sub{ '<ul>' . &ls(map(&denc($_),@_[1..$#_])) . '</ul>' },
        'comment'  => \&plugin_comment ,
        'sitename' => sub{ &enc( $::config{sitename} || '') } ,
        'br'       => sub{ '<br>' } ,
        'clear'    => sub{ '<br clear="all">' } ,
        'lt'       => sub{ '&lt;' } ,
        'gt'       => sub{ '&gt;' } ,
        'amp'      => sub{ '&amp;' } ,
        'lp'       => sub{ '&#40;' } ,
        'rp'       => sub{ '&#41;' } ,
        'lb'       => sub{ '&#91;' } ,
        'rb'       => sub{ '&#93;' } ,
        'll'       => sub{ '&#40;&#40;' },
        'rr'       => sub{ '&#41;&#41;' },
        'vl'       => sub{ '&#124;' },
        'v'        => sub{ '&' . ($#_ >= 1 ? $_[1] : 'amp') . ';' },
        'bq'       => sub{ '&#96;' },
        'null'     => sub{ '' } ,
        'outline'  => \&plugin_outline ,
        '#'        => sub{ $::ref{$_[2]||0} = ++$::cnt{$_[1]||0} } ,
        'remote_addr' => sub{ $::remote_addr; } ,
        'taglist'  => \&plugin_taglist ,
        'title'  => sub{ ($::page_alias = $_[0]->{argv}) =~ s/<[^>]*>//g; $::page_alias },
        'ref' => \&plugin_ref,
    );

    %::action_plugin = (
        'index'         => sub{ &do_index('recent','rindex','-i','-a','-l');  },
        'rindex'        => sub{ &do_index('recent','index' ,'-i','-a','-l','-r'); },
        'older'         => sub{ &do_index('recent','index' ,'-i','-a','-l','-t'); },
        'recent'        => sub{ &do_index('older' ,'index' ,'-i','-a','-l','-t','-r');},
        '?'             => \&action_seek ,
        'edt'           => \&action_edit ,
        'passwd'        => \&action_passwd ,
        'comment'       => \&action_comment ,
        'Delete'        => \&action_delete ,
        'Commit'        => \&action_commit ,
        'Preview'       => \&action_preview ,
        'rollback'      => \&action_rollback ,
        'rename'        => \&action_rename ,
        'Upload'        => \&action_upload ,
        'tools'         => \&action_tools ,
        'preferences'   => \&action_preferences ,
        'new'           => \&action_new ,
        'Freeze'        => \&action_freeze_multipage ,
        'Fresh'         => \&action_fresh_multipage ,
        'Freeze/Fresh'  => \&action_freeze_or_fresh ,
        'signin'        => \&action_signin ,
        'signout'       => \&action_signout ,
        'Cut'           => \&action_cut ,
        'Paste'         => \&action_paste ,
        '+tag'          => \&action_tagplus ,
        '-tag'          => \&action_tagminus ,
    );

    @::http_header = ( "Content-type: text/html; charset=$::charset" );

    @::html_header = (
      qq(<meta http-equiv="Content-Type" content="text/html; charset=$::charset">\n<meta http-equiv="Content-Style-Type" content="text/css">\n<meta name="generator" content="markdowned wifky $::version">\n<link rel="start" href="$::me">\n<link rel="index" href="$::me?a=index">)
    );

    @::body_header = (
        qq{<form name="newpage" action="$::postme" method="post"
            style="display:none"><input type="hidden" name="p" />
            <input type="hidden" name="a" value="edt" /></form>},
        $::config{body_header}||'' ,
    );

    %::menubar = (
        '100_FrontPage' => [
            &anchor($::config{FrontPage} , undef  ) ,
        ],
        '600_Index' => [
            &anchor('Index',{a=>'index'}) ,
            &anchor('Recent',{a=>'recent'}) ,
        ],
    );
    if( !&is('lonely') || &is_signed() ){
        my $title=&make_default_pagename_();
        $::menubar{'200_New'} = [
            qq|<a href="$::me?a=new" onClick="JavaScript:if(document.newpage.p.value=prompt('Create a new page','$title')){document.newpage.submit()};return false;">New</a>| ,
        ];
    }
    @::menubar = ();
    if( &is_signed() ){
        push( @{$::menubar{'100_FrontPage'}} ,
            &anchor('.Sidebar',  {p=>'.Sidebar'}) ,
            &anchor('.Header' ,  {p=>'.Header'}) ,
            &anchor('.Signature',{p=>'.Signature'}) ,
            &anchor('.Footer',   {p=>'.Footer'}) ,
            &anchor('.Help'   ,  {p=>'.Help'}) ,
            &anchor('.CSS'    ,  {p=>$::config{CSS}} ) ,
        );

        $::menubar{'900_Sign'} = [
            &anchor('SignOut',   {a=>'signout'},{rel=>'nofollow'}) ,
            &anchor('ChangeSign',{a=>'passwd'},{rel=>'nofollow'}) ,
        ];
        $::menubar{'500_Tools'} = [
            &anchor('Tools',{a=>'tools'},{rel=>'nofollow'})
        ];
    }else{
        my $p={a=>'signin'};
        if( ($ENV{REQUEST_METHOD}||'') eq 'GET' ){
            while( my ($key,$val)=each %::form ){
                $p->{$key} ||= $val ;
            }
        }
        $::menubar{'900_SignIn'} = &anchor('SignIn',$p,{rel=>'nofollow'});
    }

    ### menubar ###
    if( $::form{p} || !exists $::form{a} ){
        my $title=$::form{p} || $::config{FrontPage};
        if( &object_exists($title) ){
            if( !&is_frozen() || &is_signed() ){
                unshift( @{$::menubar{'300_Edit'}} ,
                    &anchor('Edit',{ a=>'edt', p=>$title},{rel=>'nofollow'})
                );
                if( &is_signed() ){
                    push( @{$::menubar{'300_Edit'}} ,
                        &anchor('Rollback',{ a=>'rollback', p=>$title },
                                    {rel=>'nofollow'}) ,
                        &anchor('Rename' , { a=>'rename' , p=>$title },
                                    {rel=>'nofollow'}) ,
                    );
                }
            }
        }elsif( !&is('lonely') || &is_signed() ){
            unshift( @{$::menubar{'300_Edit'}} ,
                &anchor('Edit',{ a=>'edt', p=>$title},{rel=>'nofollow'})
            );
        }
    }
    @::copyright = (
        qq(Generated by <a href="https://github.com/zetamatta/markdowned_wifky">markdowned_wifky</a> $::version with Perl $])
    );

    %::preferences = (
        '*General Options*' => [
            { desc=>'Debug mode' , name=>'debugmode' , type=>'checkbox' } ,
            { desc=>'Archive mode' , name=>'archivemode' , type=>'checkbox' } ,
            { desc=>'Convert CRLF to <br>' ,
              name=>'autocrlf' , type=>'checkbox' } ,
            { desc=>'The sitename', name=>'sitename', size=>40 },
            { desc=>'Enable link to file://...', name=>'locallink' ,
              type=>'checkbox' },
            { desc=>'Forbid any one but administrator creating a new page.' ,
              name=>'lonely' , type=>'checkbox' },
            { desc=>'Target value for external link.',name=>'target'},
            { desc=>'Pagename(s) for CSS (1-line for 1-page)' ,
              name=>'CSS' , type=>'textarea' , rows=>2 },
            { desc=>'Pagename for FrontPage'  , name=>'FrontPage' , size=>40 },
            { desc=>'HTML-Code after <body> (for banner)' ,
              name=>'body_header' , type=>'textarea' , rows=>2 },
            { desc=>'Not found to new page' , name=>'notfound2newpage' , 
              type=>'checkbox' },
            { desc=>'Section mark', name=>'sectionmark', size=>3 } ,
            { desc=>'Subsection mark' , name=>'subsectionmark' , size=>3 } ,
            { desc=>'Subsubsection mark' , name=>'subsubsectionmark' , size=>3 } ,
            { desc=>'Ignore IP Address for Administrator' , name=>'ignore_addr' , 
              type=>'checkbox' },
            { desc=>'Signin Timeout hours(default:24hours)' ,
              name=>'signin_timeout' , size=>2 },
	    { desc=>'Time Zone string(for example, JST-9 )' ,
	      name=>'TZ' , size=>6 } ,
            { desc=>'Default pagename format(macro:%Y,%y,%m,%d,%H,%M,%S)' ,
              name=>'default_pagename_format' , size=>40 },
            { desc=>'Default <title> format(default: "%S %- %P %(%A%)" )' ,
              name=>'default_titletag_format' , size=>20 },
        ],
    );
    %::inline_syntax_plugin = (
        '200_innerlink2' => \&preprocess_innerlink ,
        '400_outerlink2' => \&preprocess_outerlink ,
        '600_htmltag'    => \&preprecess_htmltag ,
        '700_decoration' => \&preprocess_decorations ,
        '800_plugin'     => \&preprocess_plugin ,
        '900_rawurl'     => \&preprocess_rawurl ,
    );
    %::block_syntax_plugin = (
        '100_list'       => \&block_listing   ,
        '200_definition' => \&block_definition ,
        '400_midashi'    => \&block_midashi ,
        '500_centering'  => \&block_centering ,
        '600_quoting'    => \&block_quoting ,
        '700_table'      => \&block_table ,
        '900_seperator'  => \&block_separator ,
        '990_normal'     => \&block_normal ,
    );
    %::call_syntax_plugin = (
        '100_verbatim'       => \&call_verbatim ,
        '200_blockhtml'      => \&call_blockhtml ,
        '500_block_syntax'   => \&call_block ,
        '800_close_sections' => \&call_close_sections ,
        '900_footer'         => \&call_footnote ,
    );
    %::final_plugin = (
        '900_verbatim' => \&unverb ,
    );

    %::form_list = (
        '000_mode'           => \&form_mode ,
        '100_textarea'       => \&form_textarea ,
        '150_label'          => \&form_label ,
        '200_preview_botton' => \&form_preview_button ,
        '300_signarea'       => \&form_signarea ,
        '400_submit'         => \&form_commit_button ,
        '500_attachemnt'     => \&form_attachment ,
    );

    @::outline = ();

    $::user_template ||= '
        <div class="main">
            <div class="header">
                &{header}
            </div><!-- header -->
            <div class="autopagerize_page_element">
                &{main}
                <div class="terminator">
                    %{.Signature}
                </div>
            </div>
            <div class="autopagerize_insert_before"></div>
            <div class="footest">
                %{.Footer}
            </div>
            <div class="copyright footer">
                &{copyright}
            </div><!-- copyright -->
        </div><!-- main -->
        <div class="sidebar">
        %{.Sidebar}
        </div><!-- sidebar -->
        &{message}';

    $::system_template ||= '
        <div class="max">
            <div class="Header">
                &{menubar}
                <h1>&{Title}</h1>
            </div><!-- Header -->
            &{main}
            <div class="copyright footer">
                &{copyright}
            </div><!-- copyright -->
        </div><!-- max -->
        &{message}';

    $::edit_template ||= '
        <div class="main">
            <div class=".Header">
                &{menubar}
                <h1>&{Title}</h1>
            </div><!-- .Header -->
            &{main}
            <div class="copyright footer">
                &{copyright}
            </div><!-- copyright -->
        </div><!-- main -->
        <div class="sidebar">
            %{.Help}
        </div>
        &{message}';

    %::default_contents = (
        &title2fname('.CSS') => <<'HERE' ,
p.centering,big{ font-size:200% }

h2{background-color:#CFC}

h3{border-width:0px 1px 1px 0px;border-style:solid}

h4{border-width:0 0 0 3mm;border-style:solid;border-color:#BFB;padding-left:1mm}

dt,span.commentator{font-weight:bold;padding:1mm}

span.comment_date{font-style:italic}

a{ text-decoration:none }

a:link{ color:green }

a:visited{ color:darkgreen }

a:hover{ text-decoration:underline }

pre,blockquote{ background-color:#DDD ; padding:2mm }

table.block{ margin-left:1cm ; border-collapse: collapse;}

table.block th,table.block td{ border:solid 1px gray;padding:1pt}

pre{
 margin: 5mm;
 white-space: -moz-pre-wrap; /* Mozilla */
 white-space: -o-pre-wrap; /* Opera 7 */
 white-space: pre-wrap; /* CSS3 */
 word-wrap: break-word; /* IE 5.5+ */
}

div.tag{  text-align:right }

a.tag{ font-size:80%; background-color:#CFC }

span.tagnum{ font-size:70% ; color:green }

span.frozen{ font-size:80% ; color:#080 ; font-weight:bold }

@media screen{
 div.sidebar{ float:right; width:25% ; word-break: break-all;font-size:90%}
 div.main{ float:left; width:70% }
}

@media print{
 div.sidebar,div.footer,div.adminmenu{ display:none }
 div.main{ width:100% }
}

HERE
    &title2fname(".Header") => <<HERE ,
((menubar))

<h1>((sitename))</h1>
HERE
    &title2fname(".Help") => <<HERE ,
# Syntax Help

## URL Link

```
[text](http://example.com/)
http://example.com/
```

## Page Link

```
[[pagename]]
[[text|pagename]]
"pagename" (only if pagename exists)
\xE3\x80\x8Cpagename\xE3\x80\x8D (only if pagename exists)
\xE3\x80\x8Epagename\xE3\x80\x8F (only if pagename exists)
```

## Image or Attachment

```
((ref FileName Title))
```

## Text Decoration

```
** Bold **
`Preformatted`
__ Underline __
== Strike ==
== DEL =={ INS }
((br)) line feed
```

## Special Letter

```
((amp)) &    ((bq)) `
((lt))  <    ((gt)) >
((lp))  (    ((rp)) )
((lb))  [    ((rb)) ] 
((ll))  ((   ((rr)) ))
```

## Headline

```
# section-name
## subsection-name
### subsubsectino-name

>> Centering and Large-font <<
```

## Itemize

```
* item1
  * item1-1
    * item1-2
```

## Table

```
|| 1-1 | 1-2 | 1-3
|| 2-1 | 2-2 | 2-3
```

## Description

```
:item
::description
```

## Quotation

```
6<
 quotation
>9
```

## Preformatted text

<blockquote>
((bq))((bq))((bq))((br))
preformatted-text((br))
((bq))((bq))((bq))
</blockquote>
HERE
    );

    @::index_columns = (
        sub{ $_[1]->{l} ? '<tt>'.&ymdhms($_[0]->{timestamp}).'</tt>' : '' } ,
        sub{ $_[1]->{i} ? '<tt>'.(1+scalar(keys %{$_[0]->{attach}})).'</tt>' : '' } ,
        sub{ anchor( &enc($_[0]->{title}) , { p=>$_[0]->{title} } ) } ,
        sub{ $_[1]->{l} ? &label2html($_[0]->{title},'span') : '' } ,
    );

    @::index_action = (
        '<input type="submit" name="a" value="Freeze" />'
        . '<input type="submit" name="a" value="Fresh" /> '
        . '<input type="text" name="tag" />'
        . '<input type="submit" name="a" value="+tag" />'
        . '<input type="submit" name="a" value="-tag" />'
    );
}

sub browser_cache_off{
    push( @::http_header,"Pragma: no-cache\r\nCache-Control: no-cache\r\nExpires: Thu, 01 Dec 1994 16:00:00 GMT" );
}

sub read_multimedia{
    my ($query_string , $cutter ) = @_;

    my @blocks = split("\r\n$cutter","\r\n$query_string");
    foreach my $block (@blocks){
        $block =~ s/\A\r?\n//;
        my ($header,$body) = split(/\r?\n\r?\n/,$block,2);
        next unless defined($header) &&
            $header =~ /^Content-Disposition:\s+form-data;\s+name=\"(\w+)\"/i;

        my $name = $1;
        if( $header =~ /filename="([^\"]+)"/ ){
            &set_form( "$name.filename" , (split(/[\/\\]/,$1))[-1] );
        }
        &set_form( $name , $body );
    }
}

sub read_simpleform{
    foreach my $p ( split(/[&;]/, $_[0]) ){
        my ($name, $value) = split(/=/, $p,2);
        defined($value) or $value = '' ;
        $value =~ s/\+/ /g;
        $value =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack('C', hex($1))/eg;
        &set_form( $name , $value );
    }
}

sub set_form{
    my ($key,$val)=@_;
    if( $key =~ /_y$/ ){
        ($key,$val) = ($` . '_t' , &deyen($val));
    }
    push(@{$::forms{$key}} , $::form{$key} = $val );
}

sub read_form{
    foreach(split(/[,;]\s*/,$ENV{'HTTP_COOKIE'}||'') ){
        $::cookie{$`}=$' if /=/;
    }
    if( exists $ENV{REQUEST_METHOD} && $ENV{REQUEST_METHOD} eq 'POST' ){
        $ENV{CONTENT_LENGTH} > 10*1024*1024 and die('Too large form data');
        my $query_string;
        read(STDIN, $query_string, $ENV{CONTENT_LENGTH});
        if( $query_string =~ /\A(--.*?)\r?\n/ ){
            &read_multimedia( $query_string , $1 );
        }else{
            &read_simpleform( $query_string );
        }
    }
    &read_simpleform( $ENV{QUERY_STRING} ) if exists $ENV{QUERY_STRING};
}

sub puts{
    $::print .= "$_\r\n" for(@_);
}

sub putsf{
    my $fmt=shift;
    $::print .= sprintf("$fmt\r\n",@_);
}

# puts with auto escaping arguments but format-string.
sub putenc{
    my $fmt=shift;
    $::print .= sprintf("$fmt\r\n",map(&enc($_),@_));
}

sub flush{
    $::final_plugin{$_}->(\$::print) for(sort keys %::final_plugin);
    print $::print;
}

sub errmsg{
    '<h1>Error !</h1><pre>'
    . &enc( $_[0] =~ /^\!([^\!]+)\!/ ? $1 : $_[0] )
    . '</pre>';
}

sub enc{
    my $s=shift;
    defined($s) or return '';
    $s =~ s/&/\&amp;/g;
    $s =~ s/</\&lt;/g;
    $s =~ s/>/\&gt;/g;
    $s =~ s/"/\&quot;/g;
    $s =~ s/'/\&#39;/g;
    $s =~ tr/\r\a\b//d;
    $s;
}

sub denc{
    my $s = shift;
    defined($s) or return '';
    $s =~ s/\&#39;/'/g;
    $s =~ s/\&lt;/</g;
    $s =~ s/\&gt;/>/g;
    $s =~ s/\&quot;/\"/g;
    $s =~ s/\&amp;/\&/g;
    $s;
}

sub yen{ # to save crlf-code into hidden.
    my $s = shift;
    $s =~ s/\^/\^y/g;
    $s =~ s/\r/\^r/g;
    $s =~ s/\n/\^n/g;
    $s =~ s/\t/\^t/g;
    $s ;
}

sub deyen{
    my $s = shift;
    $s =~ s/\^t/\t/g;
    $s =~ s/\^n/\n/g;
    $s =~ s/\^r/\r/g;
    $s =~ s/\^y/\^/g;
    $s ;
}

sub mtimeraw{
    $::timestamp{$_[0]} ||= (-f $_[0] ? ( stat(_) )[9] : 0);
}

sub mtime{
    &ymdhms( &mtimeraw(@_) );
}

sub ymdhms{
    my $tm=$_[0] or return '0000/00/00 00:00:00';
    my @tm=localtime( $tm );
    sprintf('%04d/%02d/%02d %02d:%02d:%02d'
        , 1900+$tm[5],1+$tm[4],@tm[3,2,1,0])
}

sub cacheoff{
    undef %::timestamp;
    undef @::etcfiles;
    undef %::contents;
    undef %::xcontents;
    undef %::label_contents;
}
sub title2mtime{
    &mtime( &title2fname(@_) );
}
sub fname2title{
    pack('h*',$_[0]);
}
sub title2fname{
    my $fn=join('__',map(unpack('h*',$_),@_) );
    if( $fn =~ /^(\w+)$/ ){
        $1;
    }else{
        die("$fn: invalid filename");
    }
}
sub percent{
    my $s = shift;
    $s =~ s/([^\w\'\.\-\*\_ ])/sprintf('%%%02X',ord($1))/eg;
    $s =~ s/ /+/g;
    $s;
}

sub myurl{
    my ($cgiprm,$sharp)=@_; $sharp ||='' ;
    ( $cgiprm && %{$cgiprm}
    ? "$::me?".join(';',map($_.'='.&percent($cgiprm->{$_}),keys %{$cgiprm}))
    : $::me ) . $sharp;
}

sub anchor{
    my ($text,$cgiprm,$attr,$sharp)=@_;
    $attr ||= {}; $attr->{href}= &myurl($cgiprm,$sharp);
    &verb('<a '.join(' ',map("$_=\"".$attr->{$_}.'"',keys %{$attr})).'>')
        . $text . '</a>';
}

sub img{
    my ($text,$cgiprm,$attr)=@_;
    $attr ||= {}; $attr->{src}=&myurl($cgiprm,''); $attr->{alt}=$text;
    '<img '.&verb(join(' ',map("$_=\"".$attr->{$_}.'"',keys %{$attr}))).'>';
}

sub title2url{ &myurl( { p=>$_[0] } ); }
sub attach2url{ &myurl( { p=>$_[0] , f=>$_[1]} );}
sub is{ $::config{$_[0]} && $::config{$_[0]} ne 'NG' ; }

sub form_mode{
    if( $::config{archivemode} ){
        &puts('<div style="clear:both" class="archivemode">archive mode</div>');
    }else{
        &puts('<div style="clear:both" class="noarchivemode">no archive mode</div>');
    }
}
sub form_label{
    my $label='';
    if( $::form{a} eq 'edt' ){
        if( my $p=$::contents{$::form{p}} ){
            $label = join(' ',keys %{$p->{label}});
        }
    }else{
        $label = $::form{label_t} || '';
        $label =~ s/ +/ /;
    }
    &putenc('<div>Tag:<textarea cols="40" rows="1" name="label_t">%s</textarea></div>',
        $label );
}

sub form_textarea{
    &putenc('<textarea style="width:100%%" cols="80" rows="20" name="text_t">%s</textarea><br>'
            , ${$_[0]} );
}

sub form_preview_button{
    &puts('<input type="submit" name="a" value="Preview">');
}
sub form_signarea{
    my $token=&is_signed();
    $token or &is_frozen() or return;

    &putenc('<input type="hidden" name="admin" value="%s">',$token);

    &puts('<input type="checkbox" name="to_freeze" value="1"');
    &puts('checked') if &is_frozen();
    &puts(' >freeze');

    my $p=$::contents{ $::form{p} };
    if( $p && $p->{timestamp} ){
        &puts('<input type="checkbox" name="sage" value="1">sage');
    }
}
sub form_commit_button{
    &puts('<input type="submit" name="a" value="Commit">');
}

sub form_attachment{
    ### &begin_day('Attachment');
    &puts('<h3>Attachment</h3>');
    &puts('<p>New:<input type="file" name="newattachment_b" size="48">');
    &puts('<input type="submit" name="a" value="Upload">&nbsp;');
    &puts('<input type="checkbox" name="append_tag" value="1" />append-tag</p>');
    if( my @attachments=&list_attachment( $::form{p} ) ){
        &puts('<p>');
        foreach my $attach (sort @attachments){
            next if $attach =~ /^\0/;
            my $fn = &title2fname($::form{p}, $attach);

            &putenc('<input type="checkbox" name="f" value="%s"' , $attach );
            if( !&is_signed() && ! &w_ok($fn) ){
                &puts(' disabled');
            }
            &putenc('><input type="text" name="dummy" readonly value="((ref &quot;%s&quot;))"
                    size="%d" style="font-family:monospace"
                    onClick="this.select();">', $attach, length($attach)+10);
            &puts('('.&anchor('download',{ a=>'cat' , p=>$::form{p} , f=>$attach } ).':' );
            &putenc('%d bytes, at %s', (stat $fn)[7],&mtime($fn));
            &puts(' <span class="frozen">&lt;frozen&gt;</span>') unless &w_ok();
            &puts(')<br>');
        }
        &puts('</p>');
        &puts('<input type="submit" name="a" value="Freeze/Fresh">') if &is_signed();
        &puts('<input type="submit" name="a" value="Cut" />') if &is_signed();
        &puts('<input type="submit" name="a" value="Delete" onClick="JavaScript:return window.confirm(\'Delete Attachments. Sure?\')">');
    }
    
    if( &is_signed() && (my @clip=&select_clipboard()) > 0 ){
        &putenc('<h3>Attachment Clipboard</h3><ul>', scalar(@clip));
        foreach my $a (@clip){
            &putenc('<li>%s</li>',&fname2title($a));
        }
        &puts('</ul><input type="submit" name="a" value="Paste" />');
    }
    ### &end_day();
}

sub print_form{
    my ($title,$newsrc,$orgsrc) = @_;

    &putenc('<div class="update"><form name="editform" action="%s"
          enctype="multipart/form-data" method="post"
          accept-charset="%s" ><input type="hidden" name="orgsrc_y" value="%s"
        ><input type="hidden" name="p" value="%s"><br>'
        , $::postme , $::charset , &yen($$orgsrc) , $title );
    $::form_list{$_}->($newsrc) for(sort keys %::form_list );
    &puts('</form></div>');
}

sub flush_header{
    my $header=join("\r\n",@::http_header);
    &unverb(\$header);
    print $header;
    print qq(\r\n\r\n<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">);
    print qq(\r\n<html lang="ja"><head>\r\n);
    $header=join("\r\n",@::html_header);
    &unverb(\$header);
    print $header,"\r\n";
}

sub print_header{
    $::final_plugin{'000_header'} = \&flush_header;
    my %arg=@_;
    push(@::html_header,'<title>' .
        &verb( sub{
            my $title = $::config{default_titletag_format}
                || '%S %- %P %(%A%)';
            $title =~ s/\%S/$::config{sitename}||''/ge;
            $title =~ s/\%P/$::form{p} ? ($::page_alias || $::form{p}) : ''/ge;
            $title =~ s/\%A/$arg{title}||''/ge;
            $title =~ s/(\s*\%[^\%])*\s*$//g;
            $title =~ s/^\s*(\%[^\%]\s*)*//g;
            $title =~ s/\%([^\%])/$1/g;
            &enc($title) 
        } ).'</title>');

    &puts('<style type="text/css"><!--
div.menubar{
    height:1.5em;
}
div.menubar div{
    position:absolute;
    z-index:100;
}
ul.mainmenu{
    margin:0px;
    padding:0px;
    width:100%;
    position:relative;
    list-style:none;
    text-align:center;
}
li.menuoff{
    position:relative;
    float:left;
    height:1.5em;
    line-height:1.5em;
    overflow:hidden;
    padding-left:1pt;
    padding-right:1pt;
}
li.menuon{
    float:left;
    background-color:white;
    line-height:1.5em;
    overflow:hidden;
    border-width:1px;border-color:black;border-style:solid;
    padding-left:1pt;
    padding-right:1pt;
}
ul.mainmenu>li.menuon{
    overflow:visible;
}
ul.submenu{
    margin:0px;
    padding:0px;
    position:relative;
    list-style:none;
}
.bqh1,.bqh2,.bqh3{
    font-weight:bold;
}
a.page_not_found{
    color:red;
}
');
    foreach my $p (split(/\s*\n\s*/,$::config{CSS}) ){
        if( my $css =&read_text($p) ){
            $css =~ s/\<\<\{([^\}]+)\}/&myurl( { p=>$p , f=>$1 } )/ge;
            $css =~ s/[<>&]//g;
            $css =~ s|/\*.*?\*/||gs;
            &puts( $css );
        }
    }
    &puts('--></style></head>');
    &puts( &is_frozen() ? '<body class="frozen">' : '<body>' );
    &puts( @::body_header );
    if( $arg{userheader} ){
        if( $arg{userheader} eq 'template' ){
            $::flag{userheader} = 'template';
        }else{
            &putenc('<div class="%s">' , $arg{divclass}||'main' );
            &print_page( title=>'.Header' , class=>'header' );
            $::flag{userheader} = 1;
        }
    }else{
        &putenc('<div class="%s">' , $arg{divclass}||'max' );
        &print_page( title =>'.Header' ,
                     source=>\$::default_contents{ &title2fname('Header')} );
    }
}

sub print_footer{ ### deprecate ###
    if( $::flag{userheader} ){
        return if $::flag{userheader} eq 'template';
        &puts('<div class="copyright footer">',@::copyright,'</div>') if @::copyright;
        &puts('</div><!-- main --><div class="sidebar">');
        &print_page( title=>'Sidebar' );
    }
    &puts('</div>');
    &puts( $messages ) if $::config{debugmode} && $messages;
    &puts('</body></html>');
}

sub print_sidebar_and_footer{ ### deprecate ###
    @::copyright=();
    &print_footer();
}
sub print_copyright{} ### deprecate ###

sub is_frozen{
    if( -r &title2fname(  $#_>=0            ? $_[0]
                        : $::form{p} && length($::form{p})>0 ? $::form{p}
                        : $::config{FrontPage}))
    {
        ! &w_ok();
    }else{
        &is('lonely');
    }
}

sub auth_check{ # If password is right, return true.
    !$::config{crypt} ||
    grep(crypt($_,$::config{crypt}) eq $::config{crypt},@{$::forms{password}})>0;
}

sub ninsho{ # If password is wrong, then die.
    &auth_check() or die('!Administrator\'s Sign is wrong!');
}

sub print_signarea{
    &puts('Sign: <input type="password" name="password">');
}

sub check_frozen{
    if( &is_frozen() ){
        my $token=&is_signed();
        unless( $token ){
            die( '!This page is frozen.!');
        }
        unless( $::form{admin} && $::form{admin} eq $token ){
            die( '!CSRF Error!' );
        }
    }
}
sub check_conflict{
    my $current_source = &read_text($::form{p});
    my $before_source  = $::form{orgsrc_t};
    if( $current_source ne $before_source ){
        die( "!Someone else modified this page after you began to edit."  );
    }
}

sub read_text{ # for text
    &read_file(&title2fname(@_));
}

sub read_object{ # for binary
    &read_file(&title2fname(@_));
}

sub read_textfile{ # for text
    &read_file;
}

sub read_file{
    open(FP,$_[0]) or return $::default_contents{ $_[0] } || '';
    local $/;
    my $object = <FP>;
    close(FP);
    defined($object) ? $object : $::default_contents{ $_[0] } || '';
}

# write object with OBJECT-NAME(S) , not filename.
sub write_object{
    my $body  = pop(@_);
    my $fname = &title2fname(@_);
    &write_file($fname,$body);
}

sub write_file{
    my ($fname,$body) = @_;

    if( length( ref($body) ? $$body : $body ) <= 0 ){
        if( unlink($fname) or rmdir($fname) ){
            &cacheoff;
        }
        0;
    }else{
        &cacheoff unless -f $fname;
        open(FP,">$fname") or die("can't write the file $fname.");
            binmode(FP);
            print FP ref($body) ? ${$body} : $body;
        close(FP);
        1;
    }
}

sub action_new{
    &print_template(
        template=>$::system_template ,
        Title => 'Create Page' ,
        main => sub {
            &begin_day();
            &putenc(qq(<form action="%s" method="post" accept-charset="%s">
                <p><input type="text" name="p" size="40" value="%s">
                <input type="hidden" name="a" value="edt">
                <input type="submit" value="Create"></p></form>)
                , $::postme , $::charset , &make_default_pagename_ );
            &end_day();
        },
    );
}

sub load_config{
    for(split(/\n/,&read_textfile('index.cgi'))){
        $::config{$1}=&deyen($2) if /^\#?([^\#\!\t ]+)\t(.*)$/;
    }
}

sub local_cookie{
    my $id;
    if( exists $ENV{LOCAL_COOKIE_FILE} && open(FP,'<'.$ENV{LOCAL_COOKIE_FILE}) ){
        $id=<FP>;
        close(FP);
    }
    $id;
}

sub int_or_default{
    (defined($_[0]) && $_[0] =~ /^\d+$/) ? $_[0] : $_[1];
}

sub is_signed{
    return $::signed if defined $::signed;

    my $id=$::cookie{$::session_cookie} || &local_cookie() || rand();

    # time(TAB)ip(TAB)cookie(TAB)onetimetoken
    for( split(/\n/,&read_textfile('session.cgi') ) ){
        $::ip{$2}=[$3,$1,$4] if /^\#(\d+)\t([^\t]+)\t([^\t]+)\t(.*)$/ 
            && $1>time - &int_or_default($::config{signin_timeout},24)*60*60;
    }

    my $t;
    if( $::form{signing} && &auth_check() ){
        # at login
        push( @::http_header , "Set-Cookie: $::session_cookie=$id" );
        $::ip{$::remote_addr} = [ $id , time , $::signed=rand() ];
    }elsif( ($t=$::ip{$::remote_addr}) && $t->[0] eq $id ){
        # in session
        $t->[1] = time;
        $::signed=$t->[2];
    }else{
        # not in
        return $::signed=0;
    }
    &save_session();
    $::signed;
}

sub is_signed_csrf{
    if( my $token=&is_signed() ){
        if( $::form{admin} && $::form{admin} eq $token ){
            $token;
        }else{
            die('!CSRF Error!');
        }
    }else{
        0;
    }
}

sub save_session{
    &lockdo( sub{
        &write_file( 'session.cgi' ,
            join("\n",map(sprintf("#%s\t%s\t%s\t%s"
                        ,$::ip{$_}->[1],$_,$::ip{$_}->[0],$::ip{$_}->[2]),
                 keys %::ip ))
        ); } , 'session.cgi'
    );
}

sub action_signin{
    &print_template(
        template => $::system_template ,
        Title=> 'Signin form',
        main=> sub{
            &begin_day();
            &putenc(qq(<form action="%s" method="POST" accept-charset="%s">
                <p>Sign: <input type="password" name="password">
                <input type="hidden" name="signing" value="Enter">
                <input type="submit" value="Enter">)
                , $::postme , $::charset , $ENV{REQUEST_METHOD} );

            while( my ($key,$val)=each %::form ){
                if( $key =~ /_t$/ ){
                    &putenc('<input type="hidden" name="%s_y" value="%s" />' ,
                                $` , &yen($val) );
                }elsif( ($key ne 'a' || $val ne 'signin') && $key !~ /_b$/ ){
                    &putenc('<input type="hidden" name="%s" value="%s" />', $key , $val );
                }
            }
            &puts('</p></form>');
            &end_day();
        }
    );
}

sub action_signout{
    if( &is_signed() ){
        delete $::ip{$::remote_addr};
        &save_session();
    }
    &transfer_url($::me);
}

sub save_config{
    my @settings;
    while( my ($key,$val)=each %::config ){
        push( @settings , '#'.$key."\t".&yen($val) ) if $val;
    }
    &lockdo( sub{ &write_file( 'index.cgi' , join("\n", @settings) ) } );
}

sub action_commit{
    eval{
        &check_frozen();
        &check_conflict();
        &do_submit();
    };
    &do_preview( $@ ) if $@;
}

sub archive{
    my @tm=localtime;
    my $source=&title2fname($::form{p});
    my $backno=&title2fname($::form{p},
        sprintf('~%02d%02d%02d_%02d%02d%02d.txt',$tm[5]%100,1+$tm[4],@tm[3,2,1,0] )
    );
    rename( $source , $backno );
    chmod( 0444 , $backno );
}

sub action_preview{
    eval{
        &check_conflict;
    };
    if( $@ ){
        &do_preview( $@ );
    }else{
        &do_preview();
    }
}

sub action_rollback{
    my $token=&is_signed();
    goto &action_signin unless $token;

    if( $::form{b} && $::form{b} eq 'Rollback' ){
        die("!CSRF Error!") unless $::form{admin} && $::form{admin} eq $token;
        my $title=$::form{p};
        my $fn=&title2fname($title);
        my $frozen=&is_frozen();
        chmod(0644,$fn) if $frozen;
        &archive() if $::config{archivemode};
        &lockdo( sub{ &write_file( $fn , \&read_text($title,$::form{f})) } , $title );
        chmod(0444,$fn) if $frozen;
        &transfer_page();
    }elsif( $::form{b} && $::form{b} eq 'Preview' ){
        my $title = $::form{p};
        my $attach = $::form{f};
        &print_template(
            template => $::system_template ,
            Title=>'Rollback Preview' ,
            main=>sub{
                &begin_day($title);
                &print_page(
                    title=>$title ,
                    source=>\&read_text($title,$attach) ,
                    index=>1,
                    main=>1
                );
                &putenc('<form action="%s" method="post">',$::postme);
                &putenc('<input type="hidden" name="admin" value="%s" />',$token );
                &puts('<input type="hidden" name="a" value="rollback"> ');
                &puts('<input type="submit" name="b" value="Rollback"> ');
                &puts('<input type="submit" name="b" value="Cancel"> ');
                &putenc('<input type="hidden" name="p" value="%s">',$title);
                &putenc('<input type="hidden" name="f" value="%s">',$attach);
                &end_day();
            }
        );
    }else{ ### menu ###
        my $title = $::form{p};
        &transfer(page=>$title,message=>'Page not found') unless &object_exists($title);

        my @attachment=&list_attachment($title);

        &print_template(
            template => $::system_template ,
            Title => 'Rollback' ,
            main => sub{
                my @archive=grep(/^\~\d{6}_\d{6}\.txt/ ,@attachment);
                &begin_day($::form{p});
                if( @archive ){
                    &putenc('<form action="%s" method="post"><select name="f">', $::postme);
                    foreach my $f(reverse sort @archive){
                        &putenc('<option value="%s">%s/%s/%s %s:%s:%s</option>',
                                $f,
                                substr($f,1,2), substr($f,3,2),  substr($f, 5,2),
                                substr($f,8,2), substr($f,10,2), substr($f,12,2),
                        );
                    }
                    &puts('</select>');
                    &putenc('<input type="hidden" name="p" value="%s">',$title);
                    &puts('<input type="hidden" name="a" value="rollback" >');
                    &puts('<input type="submit" name="b" value="Preview">');
                    &puts('</form>');
                }else{
                    &puts('<p>no archive files.</p>');
                }
                &end_day()
            }
        );
    }
}

sub action_passwd{
    goto &action_signin unless &is_signed();

    if( $::form{b} ){
        unless( auth_check() ){
            &transfer(url=>&myurl({a=>'passwd'}),
                      title=>'Failure' , message=>'Old sign is wrong.');
        }
        my ($p1,$p2) = ( $::form{p1} , $::form{p2} );
        if( $p1 ne $p2 ){
            &transfer(url=>&myurl({a=>'passwd'}),
                      title=>'Failure' , message=>'New signs differs');
        }
        my @salts=('0'..'9','A'..'Z','a'..'z',".","/");
        $::config{crypt} = crypt($p1,$salts[ int(rand(64)) ].$salts[ int(rand(65)) ]);
        &save_config;
        &transfer(url=>$::me,title=>'Succeeded',message=>'Succeeded to change sign');
    }else{
        &print_template(
            template => $::system_template ,
            Title => 'Change Sign' ,
            main => sub{
                &putenc('<form action="%s" method="post">
                    <ul>
                     <li>Old Sign:<input name="password" type="password" size="40"></li>
                     <li>New Sign(1):<input name="p1" type="password" size="40"></li>
                     <li>New Sign(2):<input name="p2" type="password" size="40"></li>
                    </ul>
                    <p><input name="a" type="hidden"  value="passwd">
                    <input type="submit" name="b" value="Submit"></p></form>',$::postme);
            }
        );
    }
}

sub action_tools{
    my $token=&is_signed();
    goto &action_signin unless $token;

    &browser_cache_off();
    push( @::html_header , <<'HEADER' );
<script language="JavaScript">
<!--
    function $(id){ return document.getElementById(id); }
    function hide(id){ $(id).style.display = 'none'; }
    function show(id){ $(id).style.display = '';     }
    var lastid="*General Options*";
// -->
</script>
HEADER

    &print_template(
        template=>$::system_template ,
        Title => 'Tools' ,
        main => sub {
            ### Section Select ###
            &puts('<form action="#"><input type="hidden" name="a" value="tools">');
            &putenc('<select onChange="if( lastid ){ hide(lastid); };show(this.options[this.selectedIndex].value);lastid=this.options[this.selectedIndex].value;return false;">' );

            foreach my $section ( sort keys %::preferences ){
                &putenc('<option value="%s">%s</option>',$section,$section);
            }
            &puts('</select></form>');

            foreach my $section (keys %::preferences){
                if( $section eq '*General Options*' ){
                    &putenc('<div id="%s" class="section">', $section );
                }else{
                    &putenc('<div id="%s" style="display:none" class="section">',
                                $section );
                }
                &begin_day($section);
                &putenc('<form action="%s" method="post" accept-charset="%s">',
                            $::postme,$::charset);
                &putenc('<input type="hidden" name="section" value="%s">',$section);
                &putenc('<input type="hidden" name="admin" value="%s">',$token);

                &puts('<ul>');
                foreach my $i ( @{$::preferences{$section}} ){
                    &puts('<li>');
                    $i->{type} ||= 'text';
                    if( $i->{type} eq 'checkbox' ){
                        &putenc('<input type="checkbox" name="config__%s" value="1"%s> %s<br>'
                            , $i->{name}
                            , ( &is($i->{name}) ? ' checked' : '' )
                            , $i->{desc}
                        );
                    }elsif( $i->{type} eq 'password' ){
                        &putenc('%s <input type="password" name="config__%s">
                                (retype)<input type="password" name="verify__%s"><br>'
                            , $i->{desc} , $i->{name} , $i->{name}
                        );
                    }elsif( $i->{type} eq 'textarea' ){
                        &putenc(
                            '%s<br><textarea name="config__%s" cols="%s" rows="%s">%s</textarea><br>'
                            , $i->{desc} , $i->{name}
                            , ($i->{cols} || 40 )
                            , ($i->{rows} ||  4 )
                            , exists $::config{$i->{name}} ? $::config{$i->{name}} : ''
                        );
                    }elsif( $i->{type} eq 'radio' ){
                        &putenc('%s<br>',$i->{desc});
                        foreach my $p (@{$i->{option}}){
                            &putenc('<input type="radio" name="config__%s" value="%s"%s>%s<br>'
                                , $i->{name}
                                , $p->[0]
                                , ( defined($::config{$i->{name}}) &&
                                    $::config{$i->{name}} eq $p->[0]
                                  ? ' checked' : '' )
                                , $p->[1] );
                        }
                    }elsif( $i->{type} eq 'select' ){
                        &putenc('%s <select name="config__%s">',$i->{desc}, $i->{name});
                        foreach my $p (@{$i->{option}}){
                            &putenc('<option value="%s"%s>%s</option>'
                                , $p->[0]
                                , ( defined($::config{$i->{name}}) &&
                                    $::config{$i->{name}} eq $p->[0]
                                  ? ' selected' : '' )
                                , $p->[1] );
                        }
                        &puts('</select>');
                    }elsif( $i->{type} eq 'a' ){
                        &putenc('<a href="%s">%s</a><br>',$i->{href},$i->{desc} );
                    }elsif( $i->{type} eq 'rem' ){
                        &putenc('%s<br>',$i->{desc} );
                    }elsif( $i->{type} eq 'function' ){
                        $i->{display}->('config__'.$i->{name},$::config{$i->{name}});
                    }else{ # text
                        &putenc(
                            '%s <input type="text" name="config__%s" value="%s" size="%s"><br>'
                            , $i->{desc} , $i->{name}
                            , exists $::config{$i->{name}} ? $::config{$i->{name}} : ''
                            , $i->{size} || 10
                        );
                    }
                    &puts('</li>');
                }
                &puts('</ul><input type="hidden" name="a" value="preferences">',
                      '<input type="submit" value="Submit"></form>' );
                &end_day();
                &puts('</div>');
            }
        }
    );
}

sub action_preferences{
    goto &action_signin unless &is_signed_csrf();

    foreach my $i ( @{$::preferences{$::form{section}}} ){
        next unless exists $i->{name};
        my $type = $i->{type} || 'text';
        my $newval= exists $::form{'config__'.$i->{name}}
                  ? $::form{'config__'.$i->{name}} : '';
        if( $type eq 'checkbox' ){
            $::config{ $i->{name} } = ($newval ? 1 : 0);
        }elsif( $type eq 'password' ){
            if( length($newval) > 0 ){
                if( $newval ne $::form{'verify__'.$i->{name}} ){
                    die('invalud value for ' . $i->{name} );
                }
                $::config{ $i->{name} } = $newval;
            }
        }else{
            $::config{ $i->{name} } = $newval;
        }
    }
    &save_config;
    &transfer_url($::me);
}

sub action_rename{
    my $token=&is_signed();
    goto &action_signin unless $token;
    my $title    = $::form{p};
    &transfer(page=>$title,message=>'Page not found') unless &object_exists($title);

    if( $::form{b} && $::form{b} eq 'body' ){
        die("!CSRF Error!") unless $::form{admin} && $::form{admin} eq $token;
        my $newtitle = $::form{newtitle};
        my $fname    = &title2fname($title);
        my $newfname = &title2fname($newtitle);
        die("!The new page name '$newtitle' is already used.!") if -f $newfname;

        my @list = map {
            my $aname=unpack('h*',$_);
            my $older="${fname}__${aname}" ;
            my $newer="${newfname}__${aname}";
            die("!The new page name '$newtitle' is already used.!") if -f $newer;
            [ $older , $newer ];
        } keys %{$::contents{$title}->{attach}};

        rename( $fname , $newfname );
        rename( $_->[0] , $_->[1] ) foreach @list;
        &transfer_page($newtitle);
    }elsif( $::form{b} && $::form{b} eq 'attachment' ){
        die("!CSRF Error!") unless $::form{admin} && $::form{admin} eq $token;
        my $older=&title2fname($title,$::form{f1});
        my $newer=&title2fname($title,$::form{f2});
        die("!The new attachment name is null.!") unless $::form{f2};
        die("!The new attachment name '$::form{f2}' is already used.!") if -f $newer;

        rename( $older , $newer );
        &transfer_page($title);
    }else{ # menu
        my @attachment=&list_attachment($title);
        return unless &object_exists($title) && &is_signed();

        &print_template(
            template => $::system_template ,
            Title => 'Rename' ,
            main => sub{
                &begin_day($::form{p});
                &putenc('<h3>Page</h3><p><form action="%s" method="post">
                    <input type="hidden"  name="a" value="rename">
                    <input type="hidden"  name="b" value="body">
                    <input type="hidden"  name="p" value="%s">
                    <input type="hidden"  name="admin" value="%s">
                    Title: <input type="text" name="newtitle" value="%s" size="80">'
                    , $::postme , $title , $token , $title );
                &puts('<br><input type="submit" name="ren" value="Submit"></form></p>');

                if( @attachment ){
                    &putenc('<h3>Attachment</h3><p>
                        <form action="%s" method="post" name="rena">
                        <input type="hidden"  name="a" value="rename">
                        <input type="hidden"  name="b" value="attachment">
                        <input type="hidden"  name="admin" value="%s">
                        <input type="hidden"  name="p" value="%s">'
                        , $::postme , $token , $title );
                    &puts('<select name="f1" onChange="document.rena.f2.value=this.options[this.selectedIndex].value;return false">');
                    &puts('<option value="" selected></option>');
                    foreach my $f (@attachment){
                        &putenc('<option value="%s">%s</option>', $f, $f);
                    }
                    &puts('</select><input type="text" name="f2" value="" size="30" />');
                    &puts('<br><input type="submit" name="rena" value="Submit"></form></p>');
                }
                &end_day();
            }
        );
    }
}

sub action_seek_found_{
    &puts(
        '<li>'.
        join(' ', map{ $_->(
            { title=>$_[0] , fname=>$_[1] , timestamp=>&mtimeraw($_[1]) } , { l=>1 } )
        } @::index_columns ).
        "</li>\n"
    );
}

sub action_seek{
    my $keyword=$::form{keyword};
    my $keyword_=&enc( $keyword );

    &print_template(
        Title => qq(Seek: "$keyword_") ,
        main => sub {
            &begin_day( qq(Seek: "$keyword") );
            &do_index_header_();
            &puts(' Last Modified Time&nbsp;Page Title</tt></li>');
            foreach my $p ( values %::contents ){
                my $title = $p->{title};
                my $fname = $p->{fname};
                if( index($title ,$keyword) >= 0 ){
                    &action_seek_found_($title,$fname);
                }elsif( open(FP,$fname) ){
                    while( <FP> ){
                        if( index($_,$keyword) >= 0 ){
                            &action_seek_found_($title,$fname);
                            last;
                        }
                    }
                    close(FP);
                }
            }
            &do_index_footer_();
            &end_day();
        },
    );
}

sub select_attachment_do{
    goto &action_signin if &is_frozen() && !&is_signed_csrf();
    my $action=shift;

    foreach my $f ( @{$::forms{f}} ){
        my $fn=&title2fname( $::form{p} , $f );
        if( &w_ok($fn) || &is_signed() ){
            $action->( $f , $fn );
        }
    }
    &cacheoff;
    &do_preview();
}

sub select_clipboard{
    map{ /^__((?:[0-9a-f][0-9a-f])+)/ ? $1 : () } @::etcfiles; 
}

sub action_cut{
    &select_attachment_do(sub{ rename( $_[1] , &title2fname( '' , $_[0] ) ); },@_);
}

sub action_paste{
    goto &action_signin if &is_frozen() && !&is_signed();
    my $body=&title2fname($::form{p});
    foreach my $attach ( &select_clipboard() ){
        my $newfn=$body . '__' . $attach;
        rename( '__'.$attach , $newfn ) unless -e $newfn;
    }
    &cacheoff;
    &do_preview();
}

sub action_delete{
    &select_attachment_do(sub{ unlink( $_[1] ) or rmdir( $_[1] ); },@_ );
}

sub action_freeze_multipage{
    goto &action_signin unless &is_signed_csrf();
    chmod( 0444 , &title2fname($_) ) for(@{$::forms{p}});
    &transfer( url=> &myurl( &filter_underscore_form() ) );
}

sub action_fresh_multipage{
    goto &action_signin unless &is_signed_csrf();
    chmod( 0600 , &title2fname($_) ) for(@{$::forms{p}});
    &transfer( url=> &myurl( &filter_underscore_form() ) );
}

sub action_freeze_or_fresh{
    goto &action_signin unless &is_signed_csrf();

    foreach my $f ( @{$::forms{f}} ){
        my $fn=&title2fname( $::form{p} , $f );
        chmod( &w_ok($fn) ? 0444 : 0666 , $fn );
    }
    &cacheoff;
    &do_preview();
}

sub action_comment{
    my $title   = $::form{p};
    my $comid   = $::form{comid};
    my $who     = $::form{who} ;
    my $comment = $::form{comment};

    if( length($comment) > 0 ){
        my $fn=&title2fname($title);
        my $frozen=&is_frozen($title);
        chmod(0644,$fn) if $frozen;
        utime( time , time , $fn ) <= 0
            and die("unable to comment to unexistant page.");
        chmod(0444,$fn) if $frozen;
        &cacheoff;
        my $fname  = &title2fname($title,"comment.$comid");
        local *FP;
        open(FP,">>$fname") or die("Can not open $fname for append");
            my @tm=localtime;
            printf FP "%04d/%02d/%02d %02d:%02d:%02d\t%s\t%s\r\n"
                , 1900+$tm[5],1+$tm[4],@tm[3,2,1,0]
                , &yen($who) , &yen($comment) ;
        close(FP);
    }
    &transfer_page;
}

sub begin_day{
    &puts('<div class="day">');
    &headline( n=>2 , body=>&enc($_[0]) , class=>'title' ) if @_;
    &puts('<div class="body">');
}

sub end_day{ &puts('</div></div>'); }

sub do_index_header_{
    if( &is_signed() ){
        &putenc( '<form name="indecs" action="%s" method="post">' , $::postme );
        unshift( @::index_columns , sub{
                '<input type="checkbox" name="p" value="'.&enc($_[0]->{title}).'" />'
            }
        );
        push( @::index_columns , sub{
                &is_frozen($_[0]->{title}) ? ' <span class="frozen">&lt;frozen&gt;</span>' : ''
            }
        );
        &putenc('<input type="hidden" name="from" value="index" />');
    }
    &puts( '<ul class="pageindex"><li><tt>' );
    if( &is_signed() ){
        &puts( '<input type="checkbox" name="all" onClick="(function(){ var p=document.indecs.p ; for( e in p ){ p[e].checked = document.indecs.all.checked } } )();" />');
    }
}

sub do_index_footer_{
    if( my $token=&is_signed() ){
        shift( @::index_columns ); # check box
        pop( @::index_columns ); # frozen mark
        &puts( '<div class="indexaction">'.join("\n",@::index_action).'</div>' );
        foreach my $key (keys %::form){
            &putenc('<input type="hidden" name="_%s" value="%s" />' ,
                $key , $::form{$key} );
        }
        &putenc( '<input type="hidden" name="admin" value="%s" />' , $token );
        &putenc( '</form>' );
    }
}

sub do_index{
    my ($t,$n,@param)=@_;

    if( $::form{tag} ){
        for my $t (@{$::forms{tag}}){
            unshift(@param,"+$t");
        }
    }

    &print_template(
        title => 'IndexPage' ,
        main  => sub{
            &begin_day('IndexPage');
            &do_index_header_();
            my %tag;
            $tag{tag}=$::form{tag} if exists $::form{tag};
            &puts( &anchor(' Last Modified Time' , { a=>$t , %tag } ) .
                    '&nbsp;&nbsp;&nbsp;' . &anchor('Page Title' , { a=>$n , %tag } ) .
                    '</tt></li>' . &ls(@param) . '</ul>' );
            &do_index_footer_();
            &end_day();
        }
    );
}

sub action_upload{
    exists $::form{p} or die('not found pagename');
    &check_frozen;
    my $fn=&title2fname( $::form{p} , $::form{'newattachment_b.filename'} );
    if( -r $fn && ! &w_ok() ){
        &do_preview('The attachment is frozen.');
    }else{
        &write_file( $fn , \$::form{'newattachment_b'} );
        if( $::form{append_tag} ){
            $::form{text_t} .= "\n((ref \"".$::form{'newattachment_b.filename'}.'"))';
        }
        &do_preview();
    }
}

sub filter_underscore_form{
    my %cgiprm;
    foreach my $key (keys %::form){
        $cgiprm{ $' } = $::form{$key} if $key =~ /^_/;
    }
    \%cgiprm;
}

sub do_tagging{
    goto &action_signin unless &is_signed_csrf();
    my $action=shift;
    foreach my $tag ( split(/\s+/,$::form{tag}) ){
        my $suffix='__00'.unpack('h*',$tag);
        foreach my $p ( @{$::forms{p}} ){
            if( (unpack('h*',$p).$suffix)=~ /^([_0-9a-f]+)$/ ){ # taint
                $action->($1);
            }
        }
    }
    &transfer( url=>&myurl( &filter_underscore_form() ) );
}

sub action_tagplus{
    &do_tagging( sub{ open(FP,'>'.$_[0]) and close(FP) } );
}

sub action_tagminus{
    &do_tagging( sub{ unlink($_[0]) } );
}

sub lockdo{
    my ($code,@title)=(@_,'LOCK');
    my $lock=&title2fname(@title);
    my $retry=0;
    while( mkdir($lock,0777)==0 ){
        sleep(1);
        if( ++$retry >= 3 ){
            die("!Disk full or file writing conflict (lockfile=$lock)!");
        }
    }
    my $rc=undef;
    eval{ $rc=$code->() };
    my $err=$@;
    rmdir $lock;
    die($err) if $err;
    $rc;
}


sub do_submit{
    my $title=$::form{p};
    my $fn=&title2fname($title);
    my $p=$::contents{$title};

    chmod(0644,$fn) if &is_frozen();

    $::hook_submit->(\$title , \$::form{text_t}) if $::hook_submit;
    if( $::form{text_t} ne $::form{orgsrc_t}  &&  $::config{archivemode} ){
        &archive();
    }
    cache_update() unless %::contents;
    if( &lockdo( sub{
        if( $p ){
            foreach my $labelfname (values %{$p->{label}}){
                unlink( $labelfname );
            }
        }
        my $file_exists=&write_file( $fn , \$::form{text_t} );
        if( $file_exists && $::form{label_t} ){
            my $label=$::form{label_t};
            while( $label =~ m/(\S+)/g ){
                local *FP;
                open(FP,'>'.$fn.'__00'.unpack('h*',$1));
                close(FP);
            }
        }
        $file_exists;
    },$::form{p} )){
        if( $::form{to_freeze} ){
            chmod(0444,$fn);
        }
        if( $::form{sage} && $p ){
            utime($p->{timestamp},$p->{timestamp},$fn)
        }
        &transfer_page();
    }else{
        &transfer_url($::me.'?a=recent');
    }
}

sub transfer{
    my %o=@_;
    my $url= defined $o{page}   ? &myurl( { p=>$o{page} } )
           : defined $o{url}    ? $o{url}
           : $::me;

    print join("\r\n",@::http_header),"\r\n\r\n";
    printf '<html><head><title>%s</title>' ,
            $o{title} || 'Moving...' ;
    unless( $::config{debugmode} && $messages ){
        print qq|<meta http-equiv="refresh" content="1;URL=$url">\n|
    }
    print '</head><body>';
    printf "<p>%s</p>\n" , $o{message} if $o{message};
    print qq|<p><a href="$url">Wait or Click Here</a></p>\n|;
    print "<p>$messages</p>\n" if $::config{debugmode} && $messages;
    print '</body></html>';
    exit(0);
}

sub transfer_url{ &transfer( url=>shift ); }
sub transfer_page{ &transfer( page=>shift || $::form{p} ); }

sub do_preview{
    goto &action_signin if &is_frozen() && !&is_signed();

    my @param=@_;
    my $title = $::form{p};
    &print_template(
        template => $::edit_template ,
        main=>sub{
            &puts(@param ? '<div class="warning">'.&errmsg($param[0]).'</div>' : '');
            &begin_day('Preview:'.$::form{p} );
            &print_page( title=>$title , source=>\$::form{text_t} , index=>1 , main=>1 );
            &end_day();
            &print_form( $title , \$::form{text_t} , \$::form{orgsrc_t} );
        },
    );
}

sub action_edit{
    goto &action_signin if &is_frozen() && !&is_signed();

    &browser_cache_off();
    my $title = $::form{p};
    my @attachment=&list_attachment($title);

    &print_template(
        template => $::edit_template ,
        Title => 'Edit' ,
        main  => sub {
            &begin_day( $title );
            my $source=&read_text($title);
            &print_form( $title , \$source , \$source );
            &end_day();
        }
    );
}

sub label2html{
    my ($title,$tag)=@_;
    my $p=$::contents{$title};
    if( $p && $p->{label} ){
        qq{ <$tag class="tag">} .
        join(' ',map{ &anchor(&enc($_),{ tag=>$_,a=>'index'},{ class=>'tag'}) }
            keys %{$p->{label}}) .
        "</$tag> ";
    }else{
        '';
    }
}

sub print_template{
    my %hash=@_;
    my $template = $hash{template} || $::user_template;
    my %default=(
        header=>sub{
            &::print_page( title=>'.Header' );
            $::flag{userheader} = 1;
            &puts(&plugin({},'menubar')) unless $::flag{menubar_printed};
        },
        message=>sub{
            $::config{debugmode} && $messages ? $messages : '';
        },
        copyright => sub{ join('',@::copyright); },
        menubar => sub {
            $::flag{menubar_printed} ? "" : &plugin({},'menubar');
        },
    );
    &print_header( userheader=>'template' );
    $template =~ s/([\&\%]){(.*?)}/&template_callback(\%default,\%hash,$1,$2)/ge;
    &puts( $template );
    &puts('</body></html>');
}
sub template_callback{
    my ($default,$hash,$mark,$word)=@_;
    if( $mark eq '&' ){
        my $target="<!-- unknown function $word-->";
        if( exists $default->{$word} ){
            $target = $default->{$word};
        }elsif( exists $hash->{$word} ){
            $target = $hash->{$word};
        }
        if( ref($target) ){
            local $::print="";
            my $value=$target->( $word );
            $::print || $value || '';
        }else{
            $target;
        }
    }else{
        local $::print='';
        &::print_page( title=>$word );
        $::print;
    }
}

sub action_view{
    my $title=$::form{p}=shift;
    &print_template(
        title => $title ,
        main  => sub{
            &begin_day( $title );
            unless( &print_page( title=>$title , index=>1 , main=>1 ) ){
                push(@::http_header,'Status: 404 Page not found.');
                &::puts( '<p>404 Page not found.</p>' );
            }
            &end_day();
        }
    );
}

sub action_not_found{
    &print_template(
        title => '400 Bad Request.',
        template => '&{main}' ,
        main  => sub{
            push(@::http_header,'Status: 400 Bad Request.');
            &puts( '<h1>400 Bad Request.</h1>' );
        }
    );
}

sub action_cat{
    my $attach=$::form{f};
    my $path=&title2fname($::form{p},$attach);

    unless( open(FP,$path) ){
        push(@::http_header,'Status: 404 Attachment not found.');
        die('!404 Attachment not found!');
    }
    binmode(FP);
    binmode(STDOUT);

    my $type= $attach =~ /\.gif$/i ? 'image/gif'
            : $attach =~ /\.jpg$/i ? 'image/jpeg'
            : $attach =~ /\.png$/i ? 'image/png'
            : $attach =~ /\.pdf$/i ? 'application/pdf'
            : $attach =~ /\.txt$/i ? 'text/plain'
            : 'application/octet-stream';

    if( $ENV{HTTP_USER_AGENT} =~ /Fire/  ||
        $ENV{HTTP_USER_AGENT} =~ /Opera/ ){
        printf qq(Content-Disposition: attachment; filename*=%s''%s\r\n),
            $::charset , $attach ;
    }else{
        if( $::charset eq 'EUC-JP' ){
            $attach =~ s/([\x80-\xFF])([\x80-\xFF])/&euc2sjis($1,$2)/ge;
        }else{
            $attach = &percent($attach);
        }
        printf qq(Content-Disposition: attachment; filename=%s\r\n),$attach;
    }
    print  qq(Content-Type: $type\r\n);
    printf qq(Content-Length: %d\r\n),( stat(FP) )[7];
    printf qq(Last-Modified: %s, %02d %s %04d %s GMT\r\n) ,
                (split(' ',scalar(gmtime((stat(FP))[9]))))[0,2,1,4,3];
    print  qq(\r\n);
    eval{ alarm(0); };
    print <FP>;
    close(FP);
    exit(0);
}

sub euc2sjis{
    my $c1=ord(shift) & 0x7F;
    my $c2=ord(shift) & 0x7F;
    if( $c1 & 1 ){
        $c2 += 0x1F;
    }else{
        $c2 += 0x7D;
    }
    if( $c2 >= 0x7F ){
        ++$c2;
    }
    $c1 = ($c1-0x21)/2 + 0x81;
    if( $c1 > 0x9F ){
        $c1 += 0x40;
    }
    pack("C2",$c1,$c2);
}

sub cache_update{
    unless( %::contents || @::etcfiles ){
        opendir(DIR,'.') or die('can\'t read work directory.');
        while( my $fn=readdir(DIR) ){
            if( my @x=($fn=~/^((?:[0-9a-f][0-9a-f])+)(?:__((?:[0-9a-f][0-9a-f])+))?$/)){
                $fn=$&; # for taint mode
                my $title=pack('h*',$x[0]);
                my $p= $::contents{$title} ||= $::xcontents{$x[0]} ||={
                    fname=>$x[0] ,
                    title=>$title ,
                    attach=>{} ,
                    label=>{} ,
                    timestamp => &mtimeraw($x[0]) ,
                    mtime => &mtime($x[0]) ,
                };
                if( $x[1] ){
                    my $aname=pack('h*',$x[1]);
                    $p->{attach}->{$aname} = $fn;
                    if( substr($x[1],0,2) eq '00' ){
                        my $label=pack('h*',substr($x[1],2));
                        push( @{$::label_contents{$label}} , $p );
                        $p->{label}->{$label} = $fn;
                    }
                }
            }else{
                push( @::etcfiles , $fn );
            }
            push(@::contents,$fn);
        }
        closedir(DIR);
    }
}

sub etcfiles{
    &cache_update() ; @::etcfiles;
}

sub directory{
    &cache_update() ; @::contents;
}

sub list_page{ # deprecated
    &cache_update() ; keys %::xcontents;
}

sub object_exists{
    &cache_update() ; exists $::contents{ $_[0] }
}

sub list_attachment{
    &cache_update();
    my $p=$::contents{$_[0]};
    $p ? keys %{$p->{attach}} : ();
}

sub print_page{
    my %args=@_;
    my $title=$args{title};
    my $html =&enc( exists $args{source} ? ${$args{source}} : &read_text($title));
    return 0 unless $html;

    &puts( &label2html($title,'div') );

    push(@::outline,
        { depth => -1 , text  => $title , title => $title , sharp => '' }
    );

    my %attachment;
    foreach my $attach ( &list_attachment($title) ){
        my $attach_ = &enc( $attach );
        my $url=&myurl( { p=>$title , f=>$attach } );

        $attachment{ $attach_ } = {
            # for compatible #
            name => $attach ,
            url  => $url ,
            tag  => $attach =~ /\.(png|gif|jpg|jpeg)$/i
                    ? qq(<img src="$url" alt="$attach_" class="inline">)
                    : qq(<a href="$url" title="$attach_" class="attachment">$attach_</a>) ,
        };
    }
    my %session=(
        title      => $title ,
        attachment => \%attachment ,
        'index'    => $args{'index'} ,
        main       => $args{main} ,
    );
    if( exists $args{class} ){
        &puts(qq(<div class="$args{class}">));
        &syntax_engine( \$html , \%session );
        &puts('</div>');
    }else{
        &syntax_engine( \$html , \%session );
    }
    1;
}

sub unverb_textonly{
    ${$_[0]} =~ s/\a\((\d+)\)/
          $1 > $#::later
          ? "(code '$1' not found)"
          : ref($::later[$1]) eq 'CODE' ? $&
          : $::later[$1]/ge;
}
sub strip_tag{
    my $text=shift;
    &unverb_textonly( \$text );
    $text =~ s/\r?\n/ /g;
    $text =~ s/\<[^\>]*\>//g;
    $text;
}

sub call_verbatim{
    ${$_[0]} =~ s!^\s*```(.*?\n)\s*```!&verb("\n\n<pre>$1</pre>\n\n")!gesm;
    ${$_[0]} =~ s!`([^`]+)`!&verb("<tt>$1</tt>")!gesm;
}

sub call_blockhtml{
    ${$_[0]} =~
    s!(?:&lt;blockquote&gt;|6&lt;)(.*?)(?:&lt;/blockquote&gt;|&gt;9)!&call_blockhtml_sub($1,$_[1],'blockquote')!gesmi;
    ${$_[0]} =~
    s!&lt;center&gt;(.*?)&lt;/center&gt;!&call_blockhtml_sub($1,$_[1],'center')!gesmi;
}

sub midashi_bq{
    my ($depth,$text,$session)=@_;
    &puts('<div class="bqh'.($depth+1).'">'.&preprocess($text,$session).'</div>');
}

sub call_blockhtml_sub{
    my ($text,$request,$tag)=@_;
    local $::print='';
    local *::midashi=*::midashi_bq;
    &call_block( \$text , $request );
    qq(\n\n<${tag} class="block">).&verb($::print)."</${tag}>\n\n";
}

sub inner_link_{
    my ($session,$symbol,$title_and_sharp) = @_;
    $title_and_sharp ||= $symbol;
    my ($title,$sharp) = split(/(?=#[pf][0-9mt])/,$title_and_sharp);

    if( $title =~ /^#/ ){
        ($title,$sharp)=($session->{title},$title);
    }else{
        $title = &denc($title);
    }

    if( &object_exists($title) ){
        &anchor( $symbol , { p=>$title } , { class=>'wikipage' } , $sharp);
    }else{
        "";
    }
}

sub inner_link{
    if( my $s=&inner_link_ ){
        $s;
    }elsif( $::config{notfound2newpage} ){
        &anchor( $_[1] , { p=>$_[2] , a=>'edt' } , { class=>'page_not_found' } );
    }else{
        qq(<blink class="page_not_found">$_[1]?</blink>);
    }
}

sub plugin_menubar{
    shift;
    $::flag{menubar_printed}=1;
    my $i=50;
    my %bar=(%::menubar , map( (sprintf('%03d_argument',++$i) => $_) , @_));
    my $out='<div class="menubar"><div><ul class="mainmenu">';
    foreach my $p (sort keys %bar){
        $out .= q|<li class="menuoff" onmouseover="this.className='menuon'" onmouseout="this.className='menuoff'">|;
        my $items=$bar{$p};
        if( ref($items) ){
            my ($first,@rest)=@{$items};
            $out .= $first;
            if( @rest ){
                $out .= '<ul class="submenu"><li>' .
                        join("</li><li>",@rest)  .
                        "</li></ul>";
            }
        }else{
            $out .= $items;
        }
        $out .= '</li>';
    }
    $out . '</ul></div></div>';
}

sub plugin_search{
    sprintf( '<div class="search_form"><form class="search" action="%s">
        <input class="search" type="text" name="keyword" size="20" value="%s">
        <input type="hidden" name="a" value="?">
        <input class="search" type="submit" value="?">
        </form></div>' ,
        $::me ,
        &enc(exists $::form{keyword} ? $::form{keyword} : '' ));
}

sub plugin_footnote{
    my $session = shift;
    my $footnotetext=$session->{argv};
    my $title=$::form{p};

    &verb( sub{
        push(@{$session->{footnotes}}, $footnotetext );

        my $i=$#{$session->{footnotes}} + 1;
        my %attr=( title=>&strip_tag($footnotetext)  );
        $attr{name}="fm$i" if $session->{index};
        '<sup>' .
        &anchor("*$i", { p=>$title } , \%attr , "#ft$i" ) .
        '</sup>' 
    });
}

sub call_footnote{
    my (undef,$session) = @_;
    &puts( &verb( sub{
        my $footnotes = $session->{footnotes};
        return "" unless $footnotes;

        my $i=0;
        my $out=qq(<div class="footnote">);
        foreach my $t (@{$footnotes}){
            ++$i;
            next unless defined $t;
            $out .= '<p class="footnote">' .
                &anchor("*$i",{ p=>$::form{p} } ,
                ($session->{index} ? { name=>"ft$i"} : undef) ,
                "#fm$i") .
                "$t</p>";
            undef $t;
        }
        $out .= '</div><!--footnote-->';
        $out;
    }));
}

sub verb{
    push( @::later , $_[0] );
    "\a($#::later)";
}

sub unverb_sub{
    my $s=shift;
    if( $s > $#::later ){
        $s="(code '$1' not found)";
    }elsif( ref($::later[$1]) eq 'CODE' ){
        $s=$::later[$s]->($1);
    }else{
        $s=$::later[$s];
    }
    &unverb(\$s);
    $s;
}

sub unverb{
    ${$_[0]} =~ s/\a\((\d+)\)/&unverb_sub($1)/ge;
}


sub plugin_outline{
    &verb(
        sub{
            my $depth=-2;
            my $ss='';
            foreach my $p( @::outline ){
                next if $p->{title} =~ /^\./;

                my $diff=$p->{depth} - $depth;
                if( $diff > 0 ){
                    $ss .= '<ul><li>' x $diff ;
                }else{
                    $diff < 0    and $ss .= "</li></ul>\n" x -$diff;
                    $depth >= 0  and $ss .= "</li>\n" ;
                    $ss .= '<li>';
                }
                $ss .= &anchor( $p->{text}, { p=>$p->{title} }, undef, $p->{sharp} );
                $depth=$p->{depth};
            }
            $ss .= '</li></ul>' x ($depth+2);
            $ss;
        }
    );
}

sub has_all_label{
    my ($page_label,$seek_label)=@_;
    foreach my $p (@{$seek_label}){
        return 0 unless exists $page_label->{$p};
    }
    1;
}

sub ls_core{
    my ($opt,@args) = @_;
    push(@args,'*') unless @args;

    my @patterns = map {
        s/([^\*\?]+)/unpack('h*',$1)/eg;
        s/\?/../g;
        s/\*/.*/g;
        '^'.$_.'$';
    } @args;

    my @list = grep{
        if( exists $opt->{'+'} && ! &has_all_label($_->{label},$opt->{'+'}) ){
            0;
        }elsif( !exists $opt->{a} && ($_->{title} =~ /^\./ || ! -f $_->{fname} ) ){
            0;
        }else{
            my $fn=$_->{fname};
            (grep{ $fn =~ $_ } @patterns) > 0;
        }
    } values %::contents;

    if( exists $opt->{t} ){
        @list = sort{ $a->{timestamp} cmp $b->{timestamp} } @list;
    }else{
        @list = sort{ $a->{title} cmp $b->{title} } @list;
    }
    @list = reverse @list if exists $opt->{r};
    if( defined (my $n=$opt->{number} || $opt->{countdown}) ){
        splice(@list,$n) if $n =~ /^\d+$/ && $#list >= $n;
    }
    @list;
}

sub parse_opt{
    my ($opt,$arg,@rest)=@_;
    foreach my $p (@rest){
        if( $p =~ /^-(\d+)$/ ){
            $opt->{number} = $opt->{countdown} = $1;
        }elsif( $p =~ /^-/ ){
            $opt->{$'} = 1;
        }elsif( $p =~ /^\+/ ){
            push(@{$opt->{'+'}} , $' );
        }else{
            push(@{$arg},$p);
        }
    }
}

sub ls{
    &parse_opt(\my %opt,\my @arg,@_);

    my $buf = '';
    foreach my $p ( &ls_core(\%opt,@arg) ){
        $buf .= '<li>'.join(' ', map{ $_->($p,\%opt) } @::index_columns )."</li>\n";
    }
    $buf;
}

sub plugin_comment{
    return '' unless $::form{p};

    my $session=shift;
    &parse_opt( \my %opt , \my @arg , @_ );
    my $comid = (shift(@arg) || '0');
    my $caption = @arg ? '<div class="caption">'.join(' ',@arg).'</div>' : '';

    exists $session->{"comment.$comid"} and return '';
    $session->{"comment.$comid"} = 1;

    my $buf = sprintf('<div class="comment" id="c_%s_%s">%s<div class="commentshort">',
                unpack('h*',$::form{p}) ,
                unpack('h*',$comid) ,
                $caption );
    my $input_form = $opt{f} ? '' : sprintf(<<HTML
<div class="form">
<form action="%s" method="post" class="comment">
<input type="hidden" name="p" value="%s">
<input type="hidden" name="a" value="comment">
<input type="hidden" name="comid" value="%s">
<div class="field name">
<input type="text" name="who" size="10" class="field">
</div><!-- div.field name -->
<div class="textarea">
<textarea name="comment" cols="60" rows="1" class="field"></textarea>
</div><!-- div.textarea -->
<div class="button">
<input type="submit" name="Comment" value="Comment">
</div><!-- div.button -->
</form>
</div><!-- div.form -->
HTML
    , $::postme , &enc($::form{p}) , &enc($comid) );

    $buf .= $input_form if $opt{r};
    my @comments = split(/\r?\n/,&read_text($::form{p} , "comment.$comid"));
    @comments = reverse @comments if $opt{r};
    for(@comments){
        my ($dt,$who,$say) = split(/\t/,$_,3);
        my $text=&enc(&deyen($say)); $text =~ s/\n/<br>/g;
        $buf .= sprintf('<p><span class="commentator">%s</span>'.
            ' %s <span class="comment_date">(%s)</span></p>'
                , &enc(&deyen($who)), $text , &enc($dt) );
    }
    $buf .= $input_form unless $opt{r};
    $buf . '</div></div>';
}

sub plugin_pagename{
    if( exists $::form{a} && (
        $::form{a} eq 'index'  || $::form{a} eq 'recent' ||
        $::form{a} eq 'rindex' || $::form{a} eq 'older'   )  ){
        'IndexPage';
    }elsif( exists $::form{keyword} ){
        &enc('Seek: '.$::form{keyword});
    }else{
        &enc( exists $::form{p} ? $::form{p} : $::config{FrontPage} );
    }
}

sub plugin_taglist{
    my $html='<div class="taglist">';
    foreach my $label(sort keys %::label_contents){
        my $list=$::label_contents{$label};
        $html .= '<span class="taglist">';
        $html .= &anchor(&enc($label),{ tag=>$label,a=>'index'},{ class=>'tag'});
        $html .= sprintf('<span class="tagnum">(%d)</span></span> ',scalar(@{$list}));
    }
    $html .= '</div>';
}

sub plugin{
    my $session=shift;
    my ($name,$param)=(map{(my $s=$_)=~s/<br>\Z//;$s} split(/\s+/,shift,2),'');
    &preprocess_plugin_after( $session->{argv} = $param );

    $param =~ s/\x02.*?\x02/"\x05".unpack('h*',$&)."\x05"/eg;
    my @param=split(/\s+/,$param);
    foreach(@param){
        s|\x05([^\x05]*)\x05|pack('h*',$1)|ge;
        s|\x02+|"\x02"x(length($&)>>1)|ge;
        &preprocess_plugin_after( $_ );
    }

    ($::inline_plugin{$name} || sub{'Plugin not found.'} )
        ->($session,@param) || '';
}

sub cr2br{
    my $s=shift;
    $s =~ s/\n/\n<br>/g;
    $s =~ s/ /&nbsp;/g;
    $s;
}

sub preprocess_innerlink{ ### [[ ... | ... ]] ###
    my ($text,$session)=@_;
    $$text =~ s!\[\[(?:([^\|\]]+)\|)?(.+?)\]\]!
        &inner_link($session,defined($1)?$1:$2,$2)!ge;
    $$text =~ s!(?<=\xE3\x80\x8C).*?(?=\xE3\x80\x8D)!&inner_link_($session,$&) || $&!ge;
    $$text =~ s!(?<=\xE3\x80\x8E).*?(?=\xE3\x80\x8F)!&inner_link_($session,$&) || $&!ge;
    $$text =~ s!(?<=&quot;).*?(?=&quot;)!&inner_link_($session,$&) || $&!ge;
}

sub preprocess_outerlink{ ### [...](http://...) style ###
    ${$_[0]} =~ s!\[([^\]]+)\]\(((?:\.\.?/|$::PROTOCOL://)[^\)]+)\)!
        &verb(sprintf('<a href="%s"%s>',$2,$::target)).$1.'</a>'!goe;
}

sub plugin_ref{
    my ($session,$nm,$label)=@_;
    my ($p,$f)=($session->{title},&denc($nm));
    $label ||= $nm;
    $label =~ s/\r*\n/ /gs;

    if( exists $session->{attachment}->{$nm} ){
        if( $nm =~ /\.png$/i || $nm =~ /\.gif$/i  || $nm =~ /\.jpe?g$/i ){
            &img( $label ,{ p=>$p , f=>$f } , { class=>'inline' } );
        }else{
            &anchor($label ,{ p=>$p , f=>$f } , { title=>$label } )
        }
    }else{
        &verb(sub{$::ref{$nm} || qq(<blink class="attachment_not_found">$nm</blink>)});
    }
}

sub preprecess_htmltag{
    ${$_[0]} =~ s!&lt;(/?(b|big|br|cite|code|del|dfn|em|hr|i|ins|kbd|q|s|samp|small|span|strike|strong|sup|sub|tt|u|var|h[1-6])\s*/?)&gt;!<$1>!gi;
}

sub preprocess_decorations{
    my $text=shift;
    $$text =~ s|^//.*$||mg;
    $$text =~ s|\*\*(.*)?\*\*|<strong>$1</strong>|gs;
    $$text =~ s|&#39;&#39;&#39;(.*?)&#39;&#39;&#39;|<strong>$1</strong>|gs;
    $$text =~ s|&#39;&#39;(.*?)&#39;&#39;|<em>$1</em>|gs;
    $$text =~ s|__(.*?)__|<u>$1</u>|gs;
    $$text =~ s|==(.*?)==\{(.*?)\}|<del>$1</del><ins>$2</ins>|gs;
    $$text =~ s|==(.*?)==|<strike>$1</strike>|gs;
    $$text =~ s/\n/<br>\n/g if $::config{autocrlf} ;
}

sub preprocess_plugin_before{
    $_[0] =~ s/&quot;/\x02/g;
    $_[0] =~ s/\(\(/\x03/g;
    $_[0] =~ s/\)\)/\x04/g;
}
sub preprocess_plugin_after{
    $_[0] =~ s/\x04/\)\)/g;
    $_[0] =~ s/\x03/\(\(/g;
    $_[0] =~ s/\x02/&quot;/g;
    
}
sub preprocess_plugin{
    my ($text,$sesion) = @_;
    &preprocess_plugin_before( $$text );
    $$text =~ s/\x03([^\x02-\x04]*?(?:\x02[^\x02]*\x02[^\x02-\x04]*?)*?)\x04/&plugin($sesion,$1)/ges;
    &preprocess_plugin_after( $$text );
}

sub preprocess_rawurl_sub{
    my $u=shift;
    if( $u =~ /\.gif$/i || $u =~ /\.jpe?g$/i || $u =~ /\.png$/ ){
        &verb(qq'<img src="$u" />');
    }else{
        &verb(qq'<a href="$u"$::target>$u</a>');
    }
}
sub preprocess_rawurl{
    my $text=shift;
    $$text = " $$text";
    $$text =~ s/([^-\"\>\w\.!~'\(\);\/?\@&=+\$,%#])($::RXURL)/
        $1.&preprocess_rawurl_sub($2)/goe;
    substr($$text,0,1)='';
}

sub preprocess{
    my ($text,$session) = @_;
    foreach my $p ( sort keys %::inline_syntax_plugin ){
        $::inline_syntax_plugin{$p}->( \$text , $session );
    }
    $text;
}

sub headline{
    my %arg=@_;
    &putsf( '<h%d%s%s>%s</h%d>' ,
                $arg{n} ,
                $arg{id}    ? qq( id="$arg{id}") : '' ,
                $arg{class} ? qq( class="$arg{class}") : '' ,
                $arg{body} ,
                $arg{n} );
}

sub midashi{
    my ($depth,$text,$session)=@_;
    $text = &preprocess($text,$session);
    my $section = ($session->{section} ||= [0,0,0,0,0]) ;

    if( $depth < 0 ){
        &headline( n=>1 , body=>$text , session=>$session );
    }else{
        grep( $_ && &puts('</div></div>'),@{$section}[$depth .. $#{$section}]);
        $section->[ $depth ]++;
        $_=0 for(@{$section}[$depth+1 .. $#{$section} ]);

        my $tag = join('.',@{$section}[0...$depth]);
        my $h    = $depth+ 3 ;
        my $cls  = ('sub' x $depth).'section' ;

        push( @::outline ,
                {
                  depth => $depth ,
                  text  => &strip_tag($text) ,
                  title => $session->{title} ,
                  sharp => "#p$tag"
                }
        );

        $text =~ s/^\+/$tag. /;
        $text = &anchor( '<span class="sanchor">' .
                         &enc($::config{"${cls}mark"}) .
                         '</span>'
                  , { p     => $session->{title} }
                  , { class => "${cls}mark sanchor" }
                  , "#p$tag"
                  ) . qq(<span class="${cls}title">$text</span>) ;

        if( $session->{main} ){
            &puts(qq(<div class="$cls x$cls">));
        }else{
            &puts(qq(<div class="x$cls">));
        }
        &headline( n=>$h, body=>$text, 
                   id=>($session->{index} && "p$tag") ,
                   session=>$session );
        if( $session->{main} ){
            &puts(qq(<div class="${cls}body x${cls}body">));
        }else{
            &puts(qq(<div class="x${cls}body">));
        }
    }
}

sub syntax_engine{
    my ($ref2html,$session) = ( ref($_[0]) ? $_[0] : \$_[0] , $_[1] );
    $session->{nest}++;
    foreach my $p ( sort keys %::call_syntax_plugin ){
        $::call_syntax_plugin{$p}->( $ref2html , $session );
    }
    $session->{nest}--;
}

sub call_block{
    my ($ref2html,$session)=@_;
    my @lines=split(/\n/,$$ref2html);
    while( scalar(@lines) > 0 ){
        foreach my $key (sort keys %::block_syntax_plugin){
            if( $::block_syntax_plugin{$key}->(\@lines,$session) ){
                # &puts("&lt;$key&gt;");
                last;
            }
        }
    }
}

sub call_close_sections{
    my ($ref2html,$session)=@_;
    exists $session->{section} and
        grep( $_ && &puts('</div></div>'),@{$session->{section}} );
}

sub cut_until_blankline{
    my $lines=shift;
    my $mode =shift || '';
    my $fragment=shift(@{$lines});
    while( scalar(@{$lines}) > 0 ){
        my $line=$lines->[0];
        if( $line =~ /^\s*$/ ){
            shift(@{$lines});
            last;
        }
        last if $line =~ /^#/;
        last if $line =~ /^\s*\-\-\-\s*$/;
        last if $lines->[1] =~ /^[\-\=]+$/;
        last if $mode ne '|' && $line =~ /^\s*\|\|/;
        last if $mode ne '*' && $line =~ /^\s*[\*\+\-]/;
        last if $mode ne ':' && $line =~ /^\s*\:/;
        last if $mode ne '<' && $line =~ /^\s*(&lt;){2,6}(?!\{)/;
        last if $mode ne '>' && $line =~ /^\s*&gt;&gt;(?!\{)/;
        last if $line =~ /^&gt;/;
        $fragment .= "\n";
        $fragment .= shift(@{$lines});
    }
    $fragment;
}

sub block_listing{ ### <UL>... block ###
    my ($lines,$session)=@_;
    my @list;
    while(1){
        my $line=$lines->[0];
        if( $line =~ /\A(\s*)[\*\+\-]/ ){
            push(@list,[ length($1) , $'] );
            shift(@{$lines});
        }elsif( /^\s*$/ ){
            last;
        }elsif( @list ){
            $list[$#list]->[1] .= shift(@{$lines});
        }
    }
    return 0 unless @list;

    my $indent=$list[0]->[0];
    my $level=0;
    &puts('<ul>');
    my $close='';
    foreach( @list ){
        my $body=&preprocess($_->[1]);
        if( $_->[0] < $indent && $level > 0 ){
            $level--;
            &puts("$close</ul></li><li>$body");
        }elsif( $_->[0] > $indent ){
            $level++;
            &puts("<ul><li>$body");
        }else{
            &puts("$close<li>$body");
        }
        $indent = $_->[0];
        $close = '</li>';
    }
    &puts( $close . ('</ul></li>' x $level).'</ul>');
    1;
}

sub block_definition{ ### <DL>...</DL> block ###
    my ($lines,$session)=@_;
    return 0 unless $lines->[0] =~ /^\s*\:/;

    my $fragment=&cut_until_blankline($lines,':');
    $fragment =~ s/\A\s*://;

    my @s=split(/\n\s*:/, &preprocess($fragment,$session) );
    &puts('<dl>',map( /^:/ ? "<dd>$'</dd>\r\n" : "<dt>$_</dt>\r\n",@s),'</dl>');
    1;
}

sub block_midashi{ ### '#'
    my ($lines,$session)=@_;
    my $line = $lines->[0];
    my $next = $lines->[1] || '';
    if( $line =~ /^\#+/ ){
        &midashi( length($&)-1 , $' , $session );
        shift(@{$lines});
    }elsif( $next =~ /^\=+$/ ){
        &midashi( 0 , $line , $session );
        splice(@{$lines},0,2);
    }elsif( $next =~ /^\-+$/ ){
        &midashi( 1 , $line , $session );
        splice(@{$lines},0,2);
    }else{
        return 0;
    }
    1;
}

sub block_centering{ ### >> ... <<
    my ($lines,$session)=@_;
    return 0 unless $lines->[0] =~ /^\s*\&gt;\&gt;(?!\{)/;

    $lines->[0] = $';
    my $fragment="";
    while( scalar(@${lines}) > 0 ){
        my $line=shift(@{$lines});
        last if $line =~ /^\s*$/;
        if( $line =~ /\&lt;\&lt;\s*$/ ){
            $fragment .= $`;
            my $s=&preprocess($fragment,$session);
            &puts('<p class="centering block" align="center">',$s,'</p>');
            return 1;
        }else{
            $fragment .= $line;
        }
    }
    &puts('<p>'.&preprocess('&gt;&gt;'.$fragment).'</p>');
    1;
}

sub block_quoting{ ### > ...
    my ($lines,$session)=@_;
    return 0 unless $lines->[0] =~ /^&gt;/s;
    my $fragment = "";
    do{
        $fragment .= $';
        shift(@$lines);
    }while( $lines->[0] =~ /^&gt;/ );
    &puts('<blockquote class="block">'.&preprocess($fragment,$session).'</blockquote>' );
    1;
}

sub block_table{ ### || ... | ... |
    my ($lines,$session)=@_;
    return 0 unless $lines->[0] =~ /^\s*\|\|/;

    my $fragment = &cut_until_blankline($lines,'|');

    my $i=0;
    $fragment =~ s/^\A\s*\|\|//;
    &puts('<table class="block">');
    foreach my $tr ( split(/\|\|/,&preprocess($fragment,$session) ) ){
        my $tag='td';
        if( $tr =~ /\A\|/ ){
            $tag = 'th'; $tr = $';
        }
        &puts( '<tr class="'.(++$i % 2 ? "odd":"even").'">',
               map("<$tag>$_</$tag>",split(/\|/,$tr) ) , '</tr>' );
    }
    &puts('</table>');
    1;
}

sub block_separator{ ### ---
    my ($lines,$session)=@_;
    return 0 unless $lines->[0] =~ /^\s*\-\-\-+\s*$/;
    shift(@{$lines});
    &puts( '<hr class="sep">' );
    1;
}

sub block_normal{
    my ($lines,$session)=@_;
    my $fragment = &cut_until_blankline($lines,'');
    if( (my $s = &preprocess($fragment,$session)) !~ /\A\s*\Z/s ){
        if( $s =~ /\A\s*<(\w+).*<\/\1[^\/]*>\s*\Z/si ){
            &puts( "<div>$s</div>" );
        }else{
            &puts("<p>$s</p>");
        }
    }
    1;
}

sub w_ok{ # equals "-w" except for root-user.
    my @stat=( $#_ < 0 ? stat(_) : stat($_[0]) );
    @stat ? $stat[2] & 0200 : -1 ;
}

sub make_default_pagename_{
    my $title=$::config{default_pagename_format} || '';
    my @tm=localtime;
    my %tm=( y=>sprintf("%02d",$tm[5] % 100) ,
             m=>sprintf("%02d",1+$tm[4] ),
             d=>sprintf("%02d",$tm[3] ),
             H=>sprintf("%02d",$tm[2] ),
             M=>sprintf("%02d",$tm[1] ),
             S=>sprintf("%02d",$tm[0] ),
             Y=>sprintf("%04d",1900+$tm[5]) );
    $title =~ s/%([ymdHMSY])/$tm{$1}/ge;
    &enc($title);
}
