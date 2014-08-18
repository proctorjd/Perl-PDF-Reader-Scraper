#!/usr/bin/perl
use lib 'libs';

package xPDFReader;
use PDF::API2;
use Data::Dumper;
use CAM::PDF;
use CAM::PDF::PageText;
use CAM::PDF::Renderer::Text;
use Data::Dumper;
use POSIX;

my $pdf = "";
my $gs = "";
our $elist = [
 #{ top => 73,left => 164, height => 13, width => 13},  
  { top => 0,left => 0, height => 1008, width => 612}

];

sub new{
 my $class = shift;
 my $self = {};

 bless $self,$class;
}

sub xtractOnePage{
  my($pagenumber,$infile,$outfile) = @_;
  unless( -e $infile){
    print STDERR "xtractOnePage input file doesn't exists \n";
    return;
  }
  my $pdf = CAM::PDF->new($infile);
  $pdf->setPrefs('','',1,1,1,1);
  $pdf->extractPages($pagenumber);
  $pdf->cleansave();
  $pdf->output($outfile);
  print STDERR "page : $pagenumber xtracted/saved as $outfile \n"; 
}

sub getAllText{
  my($pdffile,$cmd) = @_;
  $cmd = $cmd || 'buildhtml' ;
  unless( -e $pdffile){
    print STDERR "findEls : input file doesn't exists \n";
    return;
  }
  my $pdf = CAM::PDF->new($pdffile);
  my $pgcnt = $pdf->numPages;
  my $steps = $pgcnt / 10;
  $steps = floor($steps);
  my @prnt;
  my @spc = map { "\s" } 0..9;
  my $islast = 0;
  my $atxt = {};
  print "[".join("",@prnt).join("",@spc)."]";
  open FH,">myfindElsResults.txt";
    print FH "";
  close FH;
  for(my $i = 1;$i<$pgcnt;$i++){
    push(@prnt,"#");
    $islast = 1 if $i == $pgcnt; 
    $atxt{$i} = [];
    my $tree = $pdf->getPageContentTree($i);  
    #print STDERR "page dim : ".Dumper($pdf->getPageDimensions($i))." \n";  
    my ($els,$txtary) = $tree->traverse('mytextreader')->getBuildHtml({ 
	gettext => 1,
	lastpage => $islast 
    });
    open FH,">>myfindElsResults.txt";
    print FH join("",@$els);
    close FH;
    #print "Dumper : ".Dumper(@$txtary)." \n";
    push(@{$atxt{$i}},@$txtary);
    if( $pgcnt > ( $steps * $#prnt )){
      push(@prnt,"#");
      pop(@spc);
      print STDOUT "[".join("",@prnt).join("",@spc)."]";
    }
  }
  print "\ndone!\n";
  #if( $cmd eq 'buildhtml'){
    #my @els = $tree->traverse('checkboxes')->getBuildHtml();
  #}
  return $atxt;
}

sub findEls{
  my($pdffile,$cmd) = @_;
  $cmd = $cmd || 'buildhtml' ;
  unless( -e $pdffile){
    print STDERR "findEls : input file doesn't exists \n";
    return;
  }
  my $pdf = CAM::PDF->new($pdffile);
  my $tree = $pdf->getPageContentTree(1);  
  print STDERR "page dim : ".Dumper($pdf->getPageDimensions(1))." \n";  
  if( $cmd eq 'buildhtml'){
    my (@els) = $tree->traverse('mytextreader')->getBuildHtml();
    #my @els = $tree->traverse('checkboxes')->getBuildHtml();
    open FH,">myfindElsResults.txt";
    print FH join("",@els);
    close FH;
  }

  return $tree->traverse('mytextreader')->getIdentifierStruct() if( $cmd eq 'getIDStruct' );

  #open XH,">misc.txt";
  #print XH $pdf->{mediabox};
  #close XH;
}

sub getIdTypeCount{
  my($row,$jType) = @_;
  my @rw = @$row;
  my $cnt = 0;
  for my $i (0..$#rw){
    $cnt ++ if( $rw[$i]->{t} eq $jType);
  }
  return $cnt;
}

my $sortprintone = 1;
sub sortRow{
  #sort row by 'x' position and remove duplicates
  my($row,$pdebug) = @_;
  my @rw = @$row;
  my @usedCols;
  my $tmp = {};
  for my $i (0..$#rw){
    my $ulist = ($i == 0)? 'n' : join("|",@usedCols);
    $tmp->{$rw[$i]->{x}}->{t} .= $rw[$i]->{t} if(exists($tmp->{$rw[$i]->{x}})); 
    $tmp->{$rw[$i]->{x}} = $rw[$i] if(!exists($tmp->{$rw[$i]->{x}}));
  }
  my @tmpr = sort { $tmp->{$b} <=> $tmp->{$a} } keys %$tmp;
  my @tmp2 = sort { $a <=> $b } @tmpr;
  my @tmp3;
  for my $t (0..$#tmp2){
    push(@tmp3,$tmp->{$tmp2[$t]});
  }
  if( $pdebug){
    open FH,">tmpSortRow.txt";
      print FH Dumper($tmp)."\n";
      print FH "tmp2 :".Dumper(@tmp2)."\n";
      print FH "tmp3 :".Dumper(@tmp3);
    close;
    $sortprintone = 0;
  }
  return @tmp3;
}

sub getIdTypeStruct{
  my($struct,$jType) = @_;
  $jType = ($jType eq '+')? '\+' : $jType ;
  my @map = @$struct;
  my $s = {};
  my $printone = 1;
  my $pdebug = 0;
  for my $i (0..$#map){
    $pdebug = ( $i == 49)? 1 : 0;
    my @tmp = &sortRow($map[$i],$pdebug);
    if($pdebug){
      open FH,">sortRow.txt";
        print FH Dumper(@tmp);
      close FH;
      $printone = 0;
    }
    my $mask = '';
    my $cnt = 0;
    $s->{$i} = { mask => '', cnt => 0 };
    for my $j (0..$#tmp){
      $s->{$i}->{cnt}++ if( $tmp[$j]->{t} =~ /$jType/);
      $s->{$i}->{mask} .= ( $tmp[$j]->{t} =~ /$jType/ )? '1' : '0';
    }
  }
  return $s;
}

sub getMaskStruct{
  my($struct) = @_;
  my @map = @$struct;
  my $s = {};
  for my $i (0..$#map){
    my @tmp = &sortRow($map[$i],$pdebug);

    my $mask = '';
    my $cnt = 0;
    $s->{$i} = { mask => '', cnt => 0 };
    for my $j (0..$#tmp){
      $s->{$i}->{cnt}++ ;
      $s->{$i}->{mask} .= $tmp[$j]->{t};
    }
  }
  return $s;
}

sub getAvgRowHeight{
  my($rpos) = @_;
  my @rw = sort { $a <=> $b} @$rpos;
  #print STDERR "rw : ".Dumper(@rw)." \n";
  return 0 if( scalar(@rw) == 0);
  my $diffs = 0;
  for my $i (0..$#rw){
    $diffs += ($rw[($i + 1)] - $rw[$i]) if( ($i + 1) < scalar(@rw) );
  }
  return ($diffs / scalar(@rw));

}

sub getSortedPattern{
  my($patt) = @_;
  my @t1 = sort {$b <=> $a} (sort { $patt->{$b} <=> $patt->{$a} } keys %$patt);
  my @ret; 
  for my $i(0..$#t1){
    $patt->{$t1[$i]}->{pos} = $i;
    push(@ret,$patt->{$t1[$i]}) if( $patt->{$t1[$i]}->{cnt} > 0);
    #$ret->{$i} = $patt->{$t1[$i]};
  }
  return \@ret;
}

sub getLowestNotUsed{
  my($alist,$used) = @_;
  my @list = @$alist;
  my @used = @$used;
  my $low = '';
  my $dnu = (scalar(@used) == 0)? 'n' : join("|",@used);
  my @tmp;
  #print STDERR "list size : ".scalar(@list)." \n";
  #print STDERR "list [".join(",",@list)."]\n";
  #@tmp = map{ $_ } grep { $_ != m/$dnu/ } @list;
 #print STDERR "used size :".scalar(@used)." \n";
 #print STDERR "used : ".join(",",@used)." \n"; 
  for my $i(0..$#list){
    next if( $list[$i] =~ /^($dnu)$/ );
    push(@tmp,$list[$i]);
  }
  #print STDERR "tmp size : ".scalar(@tmp)." \n";
  #print STDERR "dnu : $dnu \n";
  for my $i(0..$#tmp){
    $low = $tmp[$i] if( $low eq '');
    $low = $tmp[$i] if( $low > $tmp[$i] );
  }
  #print STDERR "low value : $low \n";
  return $low;
}

sub filterHashWithHash{
  my($h1,$h2,$cfg) = @_;
  my @h1a = sort {$b <=> $a} (sort { $h1->{$b} <=> $h1->{$a} } keys %$h1);
  my @h2a = sort {$b <=> $a} (sort { $h2->{$b} <=> $h2->{$a} } keys %$h2);
  my $recursv = $cfg->{recursv};
  my @used = @{$cfg->{usedrows}};
  my $map = $cfg->{mapd};
  my @mapped = sort {$b <=> $a} (sort { $map->{$b} <=> $map->{$a} } keys %$map);
  my $startpos = (scalar(@mapped) > 0)? $mapped[$#mapped] : 0;
print STDERR "h1 ".(keys %$h1)." \n"; 
  #&filterHashWithHash($h1,$h2,$startpos++) if( !exists($h1->{$startpos}) && ($startpos < scalar(@h1a)));

  for my $i($startpos..$#h1a){
    my @tmp = @{$h1->{$i}};
    #print STDERR "stmp size ".scalar(@tmp)." \n";
    if( scalar(@tmp) == 0 ){
      $map->{$i} = { 
        x =>'',
        matches => \@tmp
      };
      next;
    }
    my $val = &getLowestNotUsed(\@tmp,\@used);
    if(defined($val) && $val ne ''){
      push(@used,$val);
      $map->{$i} = {
        x => $val,
        matches => \@tmp
      };
    }
  }

  return $map;
}

sub filterFoundHash{
  my($hash) = @_;
  my @idx = sort {$b <=> $a} (sort { $hash->{$b} <=> $hash->{$a} } keys %$hash);
  my $ret = {};
  my $revMap = {};
  for my $k(0..$#idx){
    my @tmp = @{$hash->{$k}};
    for my $y(0..$#tmp){
      $revMap->{$tmp[$y]} = [] if( !exists($revMap->{$tmp[$y]}) );
      push(@{$revMap->{$tmp[$y]}},$k);
    }
  } 
 
  #open FH,">revMap.txt";
  #  print FH Dumper($revMap);
  #close FH; 

  $ret = &filterHashWithHash(
    $hash,
    $revMap,
    {
      recursv => 0,
      usedrows =>[],
      mapd => {}
    }
  );
  open FH,">mapped.txt";
  print FH Dumper($ret);
  close FH;
  return $ret;
}

sub findPattern{
  #look for the pattern2 in pattern1
  #my($pattern1,$str1,$pattern2,$str2) = @_;
  my($pattern1,$pattern2) = @_;
  my @p1 = @{&getSortedPattern($pattern1)};
  my @p2 = @{&getSortedPattern($pattern2)};

  print STDERR "p1 size : ".scalar(@p1)." \n";
  print STDERR "p2 size : ".scalar(@p2)." \n";

  #open FH,">pattern.txt";
  #  print FH Dumper($p1);
  #close FH;
  my $found = {};
  my $fcntr = 0;
  my @frows;
  for my $i (0..$#p1){
    my $p1row = $p1[$i];
    #$p1row->{mask} =~ s/(1.*1)/$1/g;
    $p1row->{mask} =~ s/(^[L|T|+]+$)/$1/g;
    my $p1mask = $1;
    #print STDERR "p1mask : $p1mask \n";
    for my $k (0..$#p2){
      my $p2row = $p2[$k];
      #$p2row->{mask} =~ s/(1.*1)/$1/g;  
      $p2row->{mask} =~ s/(^[L|T|+]+$)/$1/g;  
      my $p2mask = $1;
      $found->{$i} = [] if(!exists($found->{$i}));
      if( $p2mask eq $p1mask ){
        push(@{$found->{$i}},$p2row->{pos});
        my $flist = join("|",@frows);
        $flist = ($flist eq '')?'n':$flist;
        if( $p2row->{pos} !~ /$flist/ ){
          $fcntr ++;
          push(@frows,$p2row->{pos});
        }
      }
    }
  }
  my $sortedf = {};
  $sortedf = &filterFoundHash($found); 
  print STDERR "matched rows : $fcntr out of ".scalar(@p2)." \n";
  open FH,">foundPatt.txt";
    print FH Dumper($found)." \n";
    print FH Dumper(\@p1)." \n";
    print FH Dumper(\@p2)." \n";
  close FH;

  my $tstruct = {};
  for my $i (0..$#p1){
    my $p1row = $p1[$i];
    $tstruct->{$p1row->{pos}} = {
      x => $sortedf->{$i}->{x},
      matches => \@{$sortedf->{$i}->{matches}}
    };
  }
  open FH,">tstruct.txt";
    print FH Dumper($tstruct);
  close FH;

  return $tstruct;
}

sub tallyMatches{
  my($hash) = @_;
  my $total = 0;
  my $match = 0;
  foreach my $t (keys %$hash){
    $total++;
    $match++ if( $hash->{$t}->{x} ne '');
  }
  return { total => $total, match => $match };
}

sub isMatch{
  my($tstr,$cstr) = @_;
  print "tmpl cols: ".scalar(@{$tstr->{colPos}})." ";
  print "comp cols: ".scalar(@{$cstr->{colPos}})."\n";
  my $return = 1;

  open FH,">tmplDump.txt";
    print FH Dumper($tstr);
  close FH;

  my @tmplrows = $tstr->{rowMap};
  my @comprows = $cstr->{rowMap};

  #abstract the identifiers to a '+' struct
  #my $tplusStr = &getIdTypeStruct(@tmplrows,'+');
  #my $cplusStr = &getIdTypeStruct(@comprows,'+');
  my $tplusStr = &getMaskStruct(@tmplrows,'+');
  my $cplusStr = &getMaskStruct(@comprows,'+');
  print STDERR "avgheight : ".&getAvgRowHeight($tstr->{colPos})." \n";
  open FH,"> templrows.txt";
    print FH Dumper($tplusStr);
  close FH;
  my $struct = {};
  $struct = &findPattern($tplusStr,$cplusStr);
  my $stats = {};
  $stats = &tallyMatches($struct);
  print STDERR "stats : ".Dumper($stats)." \n";  

  #my $processing = 0;
  #for my $i (0..$#tmplrows){
  #  my @tmp = @{$tmplrows[$i]};
  #  for my $r (0..$#comprows){
  #    my $coldiff = abs( scalar(@tmp) - scalar(@{$comprows[$r]}) );
  #    my $tdiff = abs( &getIdTypeCount(@tmp,'+') - &getIdTypeCount(@{$comprows[$r]},'+') );
  #    return 0 if( $processing && $tdiff > 3 );
  #    $processing = 1 if( $tdiff < 3 && !$processing );
  #  }
  #}

  return $return;
}

sub comparePDF{
  my($tmplPDF,$compPDF) = @_;
  my $tmplSTRUCT = {};
  my $compSTRUCT = {};
  $tmplSTRUCT = &findEls($tmplPDF,'getIDStruct');
  $compSTRUCT = &findEls($compPDF,'getIDStruct');
  if( &isMatch($tmplSTRUCT,$compSTRUCT) ){
    print "match \n";
  }else{
    print "no match \n";
  }
}

sub openPDF{
 my($pdfile) = @_;
 print STDERR "file : $pdfile\n";
 #$pdf = PDF::API2->open($pdfile);
 $pdf = CAM::PDF->new($pdfile);
 my $pdfvers = $pdf->{pdfversion};
 print STDERR "num of pages ".$pdf->numPages." \n";  
 print STDERR "pdf version : $pdfvers \n";  
 print STDERR "prefs : ".Dumper($pdf->getPrefs())." \n";  
 $pdf->setPrefs('','',1,1,1,1);  
 my $tree = $pdf->getPageContentTree(11);  
 my $gs = $tree->computeGS(1);  
 print "ref doc:".ref($gs->{refs}->{doc})." \n";  
 #my @test = $tree->traverse('checkboxes')->getRects();
 my @fields = $pdf->getFormFieldList();
 open FH,'>gsdump.txt';
 print FH Dumper(@fields);
 close FH;
 $pdf->cleansave();
 print STDERR "Done!\n";

}

package mytextreader;
#use parent 'CAM::PDF::GS';
use base 'CAM::PDF::GS';
use Data::Dumper;
use POSIX;

sub renderText
{
   my $self = shift;
   my $string = shift;
   my $width = shift;
   
   my $fontsize = $self->{Tfs};
   my $fontname = $self->{Tf};
   my($setx,$sety) = $self->textToDevice(0,0);
   $setx += $width;
   #push(@{$self->{refs}->{buildhtml}},"<div class='dtext' style='width:auto;height:auto;bottom:".$sety.";left:".$setx.";font-size:$fontsize;font-family:".$fontname.";color:blue;'>".$string."</div>");

   # noop, override in subclasses
   return;
}


#package checkboxes;
#use parent 'CAM::PDF::GS::NoText';
#use Data::Dumper;


my $lineAdjustments = {};
sub new {
  my ($pkg, @args) = @_;
  #print STDERR "elist :".Dumper($elist)." \n";
  my $self = $pkg->SUPER::new(@args);
  $self->{refs}->{rects} = [];
  $self->{refs}->{foundPos} = []; #array of objects { x, y, 'type'}
  $self->{refs}->{sRows} = [];
  $self->{refs}->{sCols} = [];
  $self->{refs}->{identifiers} = [];
  $self->{refs}->{pdftemplate} = [];
  $self->{refs}->{templatehtml} = [];
  $self->{refs}->{buildhtml} = [];
  $self->{refs}->{buildhtml} = [
    '<html><head>',
    '<style type="text/css">',
    '.name { color:red; }',
    '.dob { color:blue; }',
    '#maindiv{position:relative;width:'.$self->{refs}->{mediabox}[2].'px;height:'.$self->{refs}->{mediabox}[3].'px;',
    'background:#ddd;border:thin solid black;float:left;}',
    '.ditems{position:absolute;border:none;background:#000;}',
    '.dtext{position:absolute;border:none;}',
    '.dident{position:absolute;border:thin solid red;font-size:1px;}',
    '.ljoint{position:absolute;border:thin solid #33FF44;font-size:1px;}',
    '.tjoint{position:absolute;border:thin solid #0099FF;font-size:1px;}',
    '</style></head><body><div id="maindiv">'

  ];
  $self->{refs}->{sPDFText} = [];
  $self->{refs}->{pdf_dim}->{pdfwidth} = $self->{refs}->{mediabox}[2];
  $self->{refs}->{pdf_dim}->{pdfheight} = $self->{refs}->{mediabox}[3];
  return $self;
}

sub getRects{
 my($self) = @_;
 return @{$self->{refs}->{rects}};
}

sub getFoundPos{
 my($self) = @_;
 print STDERR "found length:".scalar(@{$self->{refs}->{foundPos}})." \n";  
 return @{$self->{refs}->{foundPos}}; 
}

sub getIdentifierStruct{
  my($self) = @_;
  $self->getIdentifiers();
  my $str = $self->createIdentifierStructure();
  return $str;
}

sub getBuildHtml{
  my($self,$args) = @_;
  my $returnTextArray = $args->{gettext} || 0;
  my $islast = $args->{lastpage} || 1;
print "return text array : $returnTextArray \n";
  $self->getIdentifiers();
  my $str = $self->createIdentifierStructure();
  push(@{$self->{refs}->{buildhtml}},'</div></body></html>') if $islast;
  open FH,">template.txt";
    #print FH Dumper($self->{refs}->{pdftemplate});
    print FH Dumper($str);
  close FH;
  #print "spdftext : ".Dumper($self->{refs}->{sPDFText})." \n"; 
  print "returning both arrays \n " if $returnTextArray;
  return ($self->{refs}->{buildhtml},$self->{refs}->{sPDFText}) if $returnTextArray;
  return @{$self->{refs}->{buildhtml}};
}

sub buildTemplate{
  my($self) = @_;
  #$self->{refs}->{templatehtml}
  #$self->{refs}->{pdftemplate}

  my $pwidth = $self->{refs}->{pdf_dim}->{pdfwidth};
  my $pheight = $self->{refs}->{pdf_dim}->{pdfheight};
  my $size = 0;
  my $margin = 0;
  if( $pwidth >= $pheight){
    $size = $pwidth ;
    $margin = ( ($pwidth - $pheight) / 2 );
  }
  if( $pheight > $pwidth){
    $size = $pheight;
    $margin = ( ($pheight - $pwidth) / 2 );
  }
  
  push(@{$self->{refs}->{pdftemplate}},{
    type => 'template',
    items =>[{
      type => 'template_size',
      width => $size,
      height => $size
    },{
      type => 'template_container',
      left => $margin,
      top => 0,
      width => $pwidth,
      height => $pheight
    }]
  });

}

sub createIdentifierStructure{
  my($self) = @_;

  #push(@{$self->{refs}->{pdftemplate}},{
  #  type => 'template_identifiers',
  #  items => \@{$self->{refs}->{identifiers}}
  #});
  my $struct = {};
  my @tmp;
  my @colcount;
  for my $i (0..$#{$self->{refs}->{identifiers}}){
    my $obj = $self->{refs}->{identifiers}[$i];
    my $clist = join("|",@colcount);
    $clist = 'n' if( $clist eq '');
    push(@colcount,$obj->{x}) unless( $obj->{x} =~ /$clist/ );
    $struct->{$obj->{y}} = [] unless( exists($struct->{$obj->{y}}) );
    push(@{$struct->{$obj->{y}}},$obj);
  }
  @tmp = sort {$struct->{$b} <=> $struct->{$a}} keys %$struct;
  my @tmp2 = sort { $b <=> $a } @tmp;
  my @idStruct;
  for my $i (0..$#tmp2){
    push(@idStruct,$struct->{$tmp2[$i]});
  }
  my @tmp3 = sort { $a <=> $b } @colcount;
  my $colstruct = {};
  for my $j (0..$#tmp3){
    $colstruct->{$tmp3[$j]} = $j;
  }
  #return $struct;
  #return \@tmp2;
  #return \@tmp3;
  #return $colstruct;
  #return \@idStruct;
  return { rowMap => \@idStruct, colMap => $colstruct, colPos => \@tmp3, rowPos => \@tmp2 };
}

sub getIdentifiers{ #it appears + are more dependable/better to match against
  my($self) = @_;
  $self->buildTemplate();
  my @identifiers;
  #print "self->{pdf_dim} dump :".Dumper($self->{refs}->{pdf_dim})." \n";
 # print STDERR "row size :".scalar(@{$self->{refs}->{sRows}})."\ncol size :".scalar(@{$self->{refs}->{sCols}})."\n";
  foreach my $i (0..@{$self->{refs}->{sRows}}){
    my $row = @{$self->{refs}->{sRows}}[$i];
    next unless defined($row);
    #print STDERR "row dump : ".Dumper($row)." \n";
    my $rowspan = ($row->{width} + $row->{x});
    my $foundIntst = 0;
    foreach my $k (0..@{$self->{refs}->{sCols}}){
      my $col = @{$self->{refs}->{sCols}}[$k];
      my $colspan = ($col->{height} + $col->{y});
      my $orthog = 0;   
      $lineAdjustments ={};
      my $localdebug = 0;
      #if( 
      #$row->{x} eq '31.199' and $row->{y} eq '935.519' &&
      #$col->{x} eq '586.079' and $col->{y} eq '48.72'
      #){
      #  $localdebug = 1;
      #}
      if( 
        $row->{x} <= $col->{x} && 
        $col->{x} <= $rowspan &&
        $row->{y} <= $colspan &&
        $col->{y} <= $row->{y}
      ){
        $orthog = 1;
      }elsif( $self->distanceTest({
        hori =>{
          x1=>$row->{x},
          y1=>$row->{y},
          x2=>$rowspan,
          y2=>$row->{y}
        },
        vert =>{
          x1=>$col->{x},
          y1=>$col->{y},
          x2=>$col->{x},
          y2=>$colspan
        }
        },$localdebug) 
      ){
        $orthog = 1;
        print "adj dump : ".Dumper($lineAdjustments)." \n" if($localdebug);
        print "############BEFORE###############\n" if($localdebug);
        print "row : ".Dumper($row)." \n" if($localdebug);
        print "col : ".Dumper($col)." \n" if($localdebug);
        print "############BEFORE###############\n" if($localdebug);

        my $cmd = $lineAdjustments->{adjon};
        my $adjval = $lineAdjustments->{dist};
        if( $cmd eq 'hori-x' ){
          $row->{x} = ($row->{x} - $adjval);
        }elsif( $cmd eq 'hori-span'){
          $row->{width} = ($row->{width} + $adjval);
        }elsif( $cmd eq 'vert-x'){
          $col->{y} = ($col->{y} - $adjval);
        }elsif( $cmd eq 'vert-span'){
          $col->{height} = ($col->{height} + $adjval);
        }
        print "############AFTER###############\n" if($localdebug);
        print "row : ".Dumper($row)." \n" if($localdebug);
        print "col : ".Dumper($col)." \n" if($localdebug);
        print "############AFTER###############\n" if($localdebug);
      }
      print "orthog :$orthog \n" if( $localdebug);
      if($orthog){
        my($l,$t,$plus,$mclass) = (0,0,0,'dident');
        $mclass = $self->getIdentifierType($row,$col);
        $mclass = 'dident' if ( $mclass eq '');
        my $idmap = { tjoint => 'T','ljoint'=> 'L',dident => '+'};
        my($x,$y) = ($col->{x},$row->{y});
        #print STDERR "x :$x and y : $y \n";
        push(@{$self->{refs}->{identifiers}},{x=>$x,y=>$y,t=>$idmap->{$mclass}});
        push(@{$self->{refs}->{buildhtml}},"<div class='$mclass' style='width:auto;height:auto;bottom:".$y.";left:".$x.";background:#999;text-align:center;' data='row(".$row->{x}.",".$row->{y}.")col(".$col->{x}.",".$col->{y}.")' col='".$col->{x}.",".$col->{y}.",".$col->{width}.",".$col->{height}."' row='".$row->{x}.",".$row->{y}.",".$row->{width}.",".$row->{height}."' >.</div>");
        $foundIntst = 1;
      }
      next if($foundIntst);
    }
  }
  push(@{$self->{refs}->{pdftemplate}},{
    type => 'template_identifiers',
    items => \@{$self->{refs}->{identifiers}}
  }); 
}

sub distanceTest{
  my($self,$points,$debug) = @_;
  my $ret = 0;
  my $pixdist = 1;
  print "points : ".Dumper($points)." \n" if($debug);
  return $ret unless( 
    ($points->{hori}->{x1} <= $points->{vert}->{x1} && $points->{vert}->{x1} <= $points->{hori}->{x2}) || 
    ($points->{vert}->{y1} <= $points->{hori}->{y1} && $points->{hori}->{y1} <= $points->{vert}->{y2}) 
  );
  my $dist = $pixdist + 1;
  #print "distance test :".Dumper($points)." \n";
  if( $points->{hori}->{x1} <= $points->{vert}->{x1} && $points->{vert}->{x1} <= $points->{hori}->{x2}){
    $dist = $self->getDistance({
      x1=> $points->{vert}->{x1}, y1=> $points->{hori}->{y1},
      x2=> $points->{vert}->{x1}, y2=> $points->{vert}->{y1}
    });
    $lineAdjustments = {dist => $dist, adjon =>'vert-x'} if($pixdist >= $dist );
    return 1 if($pixdist >= $dist );
    $dist = $self->getDistance({
      x1=> $points->{vert}->{x1}, y1=> $points->{hori}->{y1},
      x2=> $points->{vert}->{x1}, y2=> $points->{vert}->{y2}
    });
    $lineAdjustments = {dist => $dist, adjon =>'vert-span'} if($pixdist >= $dist );
    return 1 if($pixdist >= $dist );
  }

  if( $points->{vert}->{y1} <= $points->{hori}->{y1} && $points->{hori}->{y1} <= $points->{vert}->{y2}){
    $dist = $self->getDistance({
      x1=> $points->{vert}->{x1}, y1=> $points->{hori}->{y1},
      x2=> $points->{hori}->{x1}, y2=> $points->{hori}->{y1}
    });
    $lineAdjustments = {dist => $dist, adjon =>'hori-x'} if($pixdist >= $dist );
    print "la dump hori-x : ".Dumper({dist => $dist, adjon =>'hori-x'})." \n" if($debug);
    return 1 if($pixdist >= $dist );
    $dist = $self->getDistance({
      x1=> $points->{vert}->{x1}, y1=> $points->{hori}->{y1},
      x2=> $points->{hori}->{x2}, y2=> $points->{hori}->{y1}
    });
    $lineAdjustments = {dist => $dist, adjon =>'hori-span'} if($pixdist >= $dist );
    print "la hori-span dump : ".Dumper({dist => $dist, adjon =>'hori-span'})." \n" if($debug);
    return 1 if($pixdist >= $dist );
  }

  print "dist : $dist \n" if( $pixdist >= $dist );
  
  return $ret;
}

sub getDistance{
  my($self,$points) = @_;
  
  my $dist = sqrt(
    ($points->{x2} - $points->{x1})**2 +
    ($points->{y2} - $points->{y1})**2
  );
  return $dist;
}


# identifier types
# L T +
sub getIdentifierType{
  my($self,$row,$col) = @_;
  my $retidtype = '';
  my $itypes = {
    'l' => 'ljoint',
    't' => 'tjoint',
    'plus' => 'plusjoint'
  };
  my $coldelta = $col->{width};
  my $rowdelta = $row->{height};
  my $colspan = $col->{y} + $col->{height};
  my $rowspan = $row->{x} + $row->{width};
  $row->{span} = $rowspan;
  $row->{deltakey} = 'y';
  $row->{delta} = $rowdelta;
  $col->{span} = $colspan;
  $col->{delta} = $coldelta;
  $col->{deltakey} = 'x';
   
        print "row : ".Dumper($row)." \n" if($localdebug);
        print "col : ".Dumper($col)." \n" if($localdebug);

  if( $self->isLjoint($row,$col) ){
    $retidtype = $itypes->{l};
  }
  if( $self->isTjoint($row,$col) && $retidtype eq '' ){
    $retidtype = $itypes->{t};
  }
  return $retidtype;
}


sub isTjoint{
  my($self,$row,$col) = @_;
  $return = 0;
  my @values = ($row,$col);

  for my $i(0..1){
    my $index = ($i == 0)? 1 : 0;
    my $pdebug = 0;

    #if(
    #  $row->{x} eq '31.199' and $row->{y} eq '935.519' &&
    #  $col->{x} eq '586.079' and $col->{y} eq '48.72'
    #){
    #  print "col dump :".Dumper($col)." \n";
    #  print "row dump :".Dumper($row)." \n";
    #  $pdebug = 1;
    #}

    $curr = $values[$i];
    $next = $values[$index];
    my $ans = 0;
    $ans = $self->doesSegmentsIntersect($curr->{deltakey},$curr,$next,$pdebug);
    return 1 if($ans);
  }
  return $return;
}

sub doesSegmentsIntersect{
  my($self,$key,$v1,$v2,$pdebug) = @_;
  my $ckey = ($key eq 'y')? 'x':'y';
  my $delta = $v1->{delta};
  my $start = $v1->{$key};
  my $smax = ($start+$delta);
  my $smin = abs($start-$delta);

  #compare w/start
  print "smin : $smin smax : $smax delta : $delta key : $key ckey : $ckey v2key : $v2->{$key} v1ckey : $v1->{$ckey} v2ckey : $v2->{$ckey} v1span : $v1->{span} v2span : $v2->{span} \n" if(defined($pdebug) && $pdebug);
  return 1 if(($smin <= $v2->{$key} && $v2->{$key} <= $smax) && ($v1->{$ckey} <= $v2->{$ckey} && $v2->{$ckey} <= $v1->{span}) );
  print "compare w/end \n" if(defined($pdebug) && $pdebug);
  #compare w/end 
  return 1 if(($smin <= $v2->{span} && $v2->{span} <= $smax) && ($v1->{$ckey} <= $v2->{$ckey} && $v2->{$ckey} <= $v1->{span}) );
  print "no match \n" if(defined($pdebug) && $pdebug);
  return 0;
}

sub isLjoint{
  my($self,$row,$col) = @_;
  $return = 0;
  my @values = ($row,$col);

  for my $i(0..1){
    my $index = ($i == 0)? 1 : 0;
    my $pdebug = 0;
    $curr = $values[$i];
    $next = $values[$index];
    if( 
      $row->{x} eq '13.199' and $row->{y} eq '974.399' &&
      $col->{x} eq '556.799' and $col->{y} eq '62.4'
    ){
      #print "col dump :".Dumper($col)." \n";
      #print "row dump :".Dumper($row)." \n";
      #$pdebug = 1;
    }
    my $ans = 0;
    #my $strkey = ($curr->{deltakey} eq 'x')? 'y' : 'x';
    my $strkey = $curr->{deltakey} ;
    $ans = $self->isSegmentsWithinDelta($curr->{$strkey},$curr->{deltakey},$curr,$next,$pdebug);
    return 1 if($ans);
    
    #$ans = $self->isSegmentsWithinDelta($curr->{x},$next->{y},$curr->{delta},$pdebug);
    #return 1 if($ans);

    #$ans = $self->isSegmentsWithinDelta($curr->{span},$curr->{deltakey},$curr,$next,$pdebug);
    #return 1 if($ans);
  }
  return $return;
}

sub isSegmentsWithinDelta{
  my($self,$start,$dkey,$v1,$v2,$prntdebug) = @_;
  #return 1 if( $v1->{x} == $v2->{x});
  my $delta = $v1->{delta};
  my $smax = ($start+$delta);
  my $smin = abs($start-$delta);
  my $ckey = ($dkey eq 'x')? 'y' : 'x';
  print "start : $start dkey : $dkey delta : $delta v2key : $v2->{$dkey} ckey : $ckey\n" if(defined($prntdebug) && $prntdebug);
  #return 1 if( abs($v1->{x} - $v2->{x}) < 1);
  #compare start/start
  return 1 if( ($smin <= $v2->{$dkey} && $v2->{$dkey} <= $smax) && ( abs($v1->{$ckey} - $v2->{$ckey}) < 1 ) );

  print "v2span : $v2->{span} smin : $smin smax : $smax v1ckey : $v1->{$ckey}  v2ckey : $v2->{$ckey}\n" if( (defined($prntdebug) && $prntdebug) );
  #compare start/end
  return 1 if( ($smin <= $v2->{span} && $v2->{span} <= $smax) && ( abs($v1->{$ckey} - $v2->{$ckey}) < 1 ) );

  print "v2span : $v2->{span} smin : $smin smax : $smax v1span : $v1->{span}  v2ckey : $v2->{$ckey}\n" if( (defined($prntdebug) && $prntdebug) );
  #compare end/end
  return 1 if( ($smin <= $v2->{span} && $v2->{span} <= $smax) && ( abs($v1->{span} - $v2->{$ckey}) <= $delta ) );

  print "v2dkey : $v2->{$dkey} smin : $smin smax : $smax v1span : $v1->{span}  v2ckey : $v2->{$ckey}\n" if( (defined($prntdebug) && $prntdebug) );
  #compare end/start
  return 1 if( ($smin <= $v2->{$dkey} && $v2->{$dkey} <= $smax) && ( abs($v1->{span} - $v2->{$ckey}) <= $delta ) );

  return 0;
}

sub getResults{
 my($self) = @_;
 $self->getIdentifiers();
 return ($self->getBuildHtml(),@{$self->{refs}->{sRows}},@{$self->{refs}->{sCols}});
}


sub updatePosition{
 my($self,$x,$y,$type) = @_;
 #print STDERR "update called x:$x y:$y type:$type \n";
   #print STDERR "MediaBox : ".$self->getValue($self->{MediaBox})." \n";  
 for my $i (0..$#{$elist}){
  my $nm = {
   x1 => @$elist[$i]->{left},
   x2 => (@$elist[$i]->{left} + @$elist[$i]->{width}),
   y1 => @$elist[$i]->{top},
   y2 => (@$elist[$i]->{top} + @$elist[$i]->{height})
  };
  #print STDERR "list left : ".$nm->{x1}." \n";
  if(
   ($nm->{x1} < $x && $x < $nm->{x2}) &&
   ($nm->{y1} < $y && $y < $nm->{y2})
  ){
   push(@{$self->{refs}->{foundPos}},{x=>$x,y=>$y,type=>$type});
   #print STDERR "found length:".scalar(@{$self->{foundPos}})." \n";
   last;
  }
 }
}

sub m{
 my($self,$x,$y) = @_;
 #($x,$y) = $self->userToDevice($x,$y);
 $self->updatePosition($x,$y,'m');
 @{$self->{start}} = @{$self->{last}} = @{$self->{current}} = ($x,$y);  
 return; 
}

sub l{
  my($self,$x,$y) = @_;
  ($x,$y) = $self->userToDevice($x,$y);
  $self->updatePosition($x,$y,'l');
  my($lastx,$lasty) = @{$self->{last}};  
  #my($lastx,$lasty) = @{$self->{current}};  
  my $width = 1;  
  my $height = 1;  
  my $sety = $lasty;  
  my $setx = $lastx;  
  my $inverted = 0;  
  if($lastx != $x){
    $width = abs($lastx - $x);
    $width =1 if( $width < 1);
    #print STDERR "x smaller than previous\n" if ($lastx > $x);
    $setx = $x if($lastx > $x);
    $inverted = 1 if($lastx > $x);
  }
  if($lasty != $y){
    $height = abs($lasty - $y);
    $height =1 if( $height < 1);
    #print STDERR "y smaller than previous\n" if ($lasty > $y);
    $sety = $y if($lasty > $y);
    $inverted = 1 if($lasty > $y);
  }
  push(@{$self->{refs}->{sRows}},{ x => $setx, y => $sety, width => $width, height => $height}) if( $width > $height);  
  push(@{$self->{refs}->{sCols}},{ x => $setx, y => $sety, width => $width, height => $height}) if( $width < $height);  
  push(@{$self->{refs}->{buildhtml}},"<div class='ditems' style='width:".$width."px;height:".$height."px;bottom:".$sety.";left:".$setx.";'></div>");
  #push(@{$self->{refs}->{buildhtml}},"<div class='ditems' style='width:".$width."px;height:".$height."px;bottom:".$sety.";left:".$setx.";'></div>");
  @{$self->{last}} = @{$self->{current}};  @{$self->{current}} = ($x,$y);  
  return; 
}

sub re{
 my $self = shift;
 my $x = shift;
 my $y = shift;
 my $w = shift;
 my $h = shift;
 #print "re called : \n";
 #($x,$y) = $self->userToDevice($x,$y);
 $self->updatePosition($x,$y,'re');
 my $width = $w;
 my $height = $h;
 $width =1 if( $width < 1);
 $height =1 if( $height < 1);
 push(@{$self->{refs}->{sRows}},{ x => $x, y => $y, width => $width, height => $height}) if( $width > $height);  
 push(@{$self->{refs}->{sCols}},{ x => $x, y => $y, width => $width, height => $height}) if( $width < $height);  
 push(@{$self->{refs}->{buildhtml}},"<div class='ditems' style='width:".$width."px;height:".$height."px;bottom:".$y.";left:".$x.";background:#999;text-align:center;'></div>");
 push(@{$self->{refs}->{rects}},{ x => $x,y=>$y,width=>$w,height=>$h});  
 @{$self->{start}} = @{$self->{last}} = @{$self->{current}} = ($x,$y);  
 return;  
 #return $self->SUPER::re($x,$y,$w,$h); 
}

sub h{
  my $self = shift;
  #print STDERR "h called \n";
  #my($x,$y) = @{$self->{current}};
  my($x,$y) = @{$self->{last}};
  ($x,$y) = $self->userToDevice($x,$y);
  my($lastx,$lasty) = @{$self->{start}};  
  my $width = 1;  
  my $height = 1;  
  my $sety = $lasty;  
  my $setx = $lastx;  
  my $inverted = 0;
  if($lastx != $x){
    $width = abs($lastx - $x);
    $width =1 if( $width < 1);
    #print STDERR "x smaller than previous\n" if ($lastx > $x);
    $setx = $x if($lastx > $x);
    $inverted = 1 if($lastx > $x);
  }
  if($lasty != $y){
    $height = abs($lasty - $y);
    $height =1 if( $height < 1);
    #print STDERR "y smaller than previous\n" if ($lasty > $y);
    $sety = $y if($lasty > $y);
    $inverted = 1 if($lasty > $y);
  }
  if( $lasty != $y && $lastx != $x){
    print "not a straight line. \n";
  }
  push(@{$self->{refs}->{sRows}},{ x => $setx, y => $sety, width => $width, height => $height}) if( $width > $height);
  push(@{$self->{refs}->{sCols}},{ x => $setx, y => $sety, width => $width, height => $height}) if( $width < $height);
  push(@{$self->{refs}->{buildhtml}},"<div class='ditems' style='width:".$width."px;height:".$height."px;bottom:".$sety.";left:".$setx.";'></div>");
  #push(@{$self->{refs}->{buildhtml}},"<div class='ditems' style='width:".$width."px;height:".$height."px;bottom:".$sety.";left:".$setx.";'></div>");

  @{$self->{last}} = @{$self->{current}};
  @{$self->{current}} = @{$self->{start}};
  return;
}

sub v
{
   my $self = shift;
   my $x1 = shift;
   my $y1 = shift;
   my $x2 = shift;
   my $y2 = shift;

   print STDERR "v called \n";
   @{$self->{last}} = @{$self->{current}};
   @{$self->{current}} = ($x2,$y2);
   return;
}

sub y    ##no critic (Homonym)
{
   my $self = shift;
   my $x1 = shift;
   my $y1 = shift;
   my $x2 = shift;
   my $y2 = shift;

   print STDERR "y called \n";
   @{$self->{last}} = @{$self->{current}};
   @{$self->{current}} = ($x2,$y2);
   return;
}


#sub Tj
#{
#   my $self = shift;
#   my $string = shift;
#   
#   #my $fontsize = $self->{Tfs};
#   #my $fontname = $self->{Tf};
#   @{$self->{last}} = $self->textToUser(0,0);
#   $self->_Tj($string);
#   @{$self->{current}} = $self->textToUser(0,0);
#   return;
#}

sub _Tj
{
   my $self = shift;
   my $string = shift;

   if (!$self->{refs}->{fm})
   {
      die "No font metrics for font $self->{Tf}";
   }

   my @parts;
   if ($self->{mode} eq 'c' || $self->{wm} == 1)
   {
      @parts = split m//xms, $string;
   }
   else
   {
      @parts = ($string);
   }
   foreach my $substr (@parts)
   {
      my $dw = $self->{refs}->{doc}->getStringWidth($self->{refs}->{fm}, $substr);
      $self->renderText($substr, $dw);
      $self->Tadvance($dw);
      my $fontsize = 10;
      my $fontname = 'Courier New';
      my($setx,$sety) = @{$self->{last}};
      my ($setx1,$sety1) = $self->userToDevice(@{$self->{last}});
      my ($setx2,$sety2) = $self->userToDevice(@{$self->{current}});
      my $strg =  $substr;
      $strg =~ s/(\w+,[\s|\w+]\w+)/\<fontxnamex\>$1\<\/font>/g;
      $strg =~ s/(\d+\/\d+\/\d+)/\<fontxdobx\>$1\<\/font>/g if defined($1);
      $strg =~ s/\s/&nbsp;/g;
      $strg =~ s/xnamex/ class="name" /g;
      $strg =~ s/xdobx/ class="dob" /g;
      my $width = ($setx2 - $setx1);
      my $height = ($sety2 - $sety1);
      #my $fontsize = (floor($height) - 2);
      push(@{$self->{refs}->{sPDFText}},$substr);
      push(@{$self->{refs}->{buildhtml}},"<div class='dtext' style='position:absolute;width:$width;height:auto;bottom:".$sety1.";left:".$setx1.";font-size:$fontsize;font-family:$fontname;white-space: nowrap;'>".$strg."</div>");
      #print "s : $substr \n";
      
   }
   return;
}

