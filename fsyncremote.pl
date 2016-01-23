#!/usr/bin/perl
use strict;
use Getopt::Long;
use Cwd;
use Cwd 'abs_path';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dumper;
use Storable qw(lock_store lock_nstore retrieve store);
# git statusv2
# lock_store \%hashprevvlan, "$PATH/hashprevvlan.hash";
# %hashdeathstatus=%{retrieve("$PATH/hashdeathstatus.hash")}; 
#- theloume na koitajoume se edirectory kai na kanoume filing, ta arxeia eioknas/video kai broume kai na krathsoume ta stoixeia tous. ta stoixeia ayta einai ta:
#- onoma arxeiou
#- md5 tvn prvtvn 1024bytes arxeiou
#- filesize
#- filedate
#- exifdate
#
#ta stoixeia ayta ta kratame se ena csv.
#
#otan ginei auto. tha mporoume na dvsoume dyo sirectory (san arguments) kai to utility tha briskei apo to csv, ta stoixeia tvn arxeivn kai tha mporei na kanei sync to ena dir me to allo, kanontaw ta svsta rename.
#dhladh:
#tha briskei ta arxeia tou src kai tha ta kanei mirror sto dst. an ena arxeio yparxei sto dst (akoma kai se allo directory) tha to kanei move.
#
#to programma tha mporei na doulepsei kai ta real directories, alla kai mono me ta csv, etsi vste na mporei na ginei kai remote sync. Sto remote sync, tha bgazei se ena text file, tis entoles, pou xreiazontai gia na metaferei mesv enos endiamesou diskou ta data.
#
#
#     inventorymd5 { "$tag:$filemd5" } }, "$hostname:$reldir/$file";
#     inventory    {"$tag:$hostname:$reldir/$file:file"}=$file;

 our($opt_h,$opt_i,$opt_s,$opt_d,$opt_c,$opt_p,$opt_dup,$opt_safe);
GetOptions(
			'h|help' => \$opt_h,
			'i=s' => \$opt_i,
			's=s' => \$opt_s,
			'd=s' => \$opt_d,
			'c|cmd=s' => \$opt_c,
			'p' => \$opt_p,
			'dup' => \$opt_dup,
			'safe=s' => \$opt_safe
			);
#('phi:d:s:c:');
$opt_c=lc $opt_c;
my (%syncenv,%inventory,%inventorymd5,%inventorysrc,%inventorydst);
my ($hostname,$numofargs,$key,$invdst,$invsrc,$md5);
my ($cwd,$cwddst,$cwdsrc);
my ($srctag,$dsttag,$srcdir,$dstdir);
my $safefolder;

$numofargs=$#ARGV;
$cwd=getcwd;
$srctag='SRC';
$dsttag='DST';
$hostname =  $ENV{'HOSTNAME'}; 


if($opt_h==1) {
    printhelp();
	exit(0);
}

if(defined($opt_p)) {
	print "printing inventories\n";
	print_inventory($opt_s) if $opt_s;
	print_inventory($opt_d) if $opt_d;
	exit(0);
}

if(defined($opt_dup) && ($numofargs>=0 ) ) {
	my @dups;
	my $i;
	#lets find abs paths of src/dst dirs, clean and without any ".", like "././othecams".
	for($key=0;$key<=$numofargs;$key++) {
		$srcdir=$ARGV[$key];
		
		chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
		chdir $cwd; 
		print "\nGenerating inventory for $cwdsrc, $cwddst\n\n";
		inventorize($cwdsrc,"DIR$key");
	}
	foreach $key (keys %inventorymd5) {
			@dups=@{ $inventorymd5{$key }};
			if($#dups>0) { 
				print "ORIG   :    ".$dups[0]."\n";
				shift @dups;
				my $n=0;
				foreach $i (@dups)
				{
					$n++;
					print "  COPY$n:    $i\n";
				}
			}
	}	
	exit(0);
}

if($opt_safe) {
		if( ! -d "$opt_safe") {
			print "folder for deleted files does not exist. Create it first!\n";
			exit(0);
		}
		$safefolder=$opt_safe;
		print "Will move files to be deleted to $safefolder\n";
}
	
if(!defined($opt_c)) {
	print "it is better to provide command with '-c' argument. We will use the default 'sync' command.\n";
}
elsif($opt_c eq 'sync' || !defined($opt_c)) {
		$opt_c='sync'; #this is the default when we haven't given the option -c cmd
		if($numofargs==1) {
			$srcdir=shift;
			$dstdir=shift;
		}
		else {
			die "we need two folders. wrong number of arguments";
		}
}
elsif($opt_c eq 'gen') {
		if($numofargs==0 && $opt_s) {
			$srcdir=shift;
		}
		elsif($numofargs==0 && $opt_d) {
			$dstdir=shift;
		}
		elsif($numofargs==0) {
			die "you need to specify if the folder is src or dst (with -s or -d)";
		}
		if($numofargs==1) {
			$srcdir=shift;
			$dstdir=shift;
		}
		if($opt_s || $opt_d) {
			$invsrc=$opt_s if $opt_s;
			$invdst=$opt_d if $opt_d;
		}
		else {
			die "When gen inventories you need to specify src or dst filenames for inventory";
		}
}
elsif( $opt_c eq 'ainb') {
		if($numofargs==1 ) {
			$srcdir=shift;
			$dstdir=shift;
		}
		else {
			die "You need to specify the A folder and the B folder, by providing two arguments.";
		}
}
else {
				printhelp();exit(0);
}


if($opt_c eq 'gen' && $numofargs==1) {
	#lets find abs paths of src/dst dirs, clean and without any ".", like "././othecams".
	$cwd=getcwd;
	chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
	chdir $cwd; chdir $dstdir;	 $cwddst=getcwd; #get absolute dst dir
	chdir $cwd;
	print "\nGenerating inventory for $cwdsrc, $cwddst\n\n";
	inventorize($cwdsrc,$srctag);
	inventorize($cwddst,$dsttag);
	foreach $key (keys %inventory) {
			if($key =~ /^$srctag/) {
				$inventorysrc{ $key }=$inventory{ $key };
			}
			if($key =~ /^$dsttag/) {
				$inventorydst{ $key }=$inventory{ $key };
			}
	}
	store \%inventorysrc, $opt_s;
	store \%inventorydst, $opt_d;
	
}
if($opt_c eq 'gen' && $numofargs==0) {
	#lets find abs paths of src/dst dirs, clean and without any ".", like "././othecams".
	$cwd=getcwd;
	if($opt_s) {
		chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
		chdir $cwd;
		print "\nGenerating inventory for SRC in $cwdsrc\n\n";
		inventorize($cwdsrc,$srctag);
		foreach $key (keys %inventory) {
			if($key =~ /^$srctag/) {
				$inventorysrc{ $key }=$inventory{ $key };
			}
		}
		store \%inventorysrc, $opt_s;
	}
	elsif($opt_d) {
		chdir $dstdir;	$cwddst=getcwd;              #get absolute src dir
		chdir $cwd;
		print "\nGenerating inventory for DEST in $cwdsrc\n\n";
		inventorize($cwddst,$dsttag);
		foreach $key (keys %inventory) {
			if($key =~ /^$dsttag/) {
				$inventorydst{ $key }=$inventory{ $key };
			}
		}
		
		store \%inventorydst, $opt_d;
		
	}
	else {
		die "error didn't generate any inventories. weird...";
	}
}

if($opt_c eq 'sync' ) {
	#lets find abs paths of src/dst dirs, clean and without any ".", like "././othecams".
	$cwd=getcwd;
	
	if( !defined($opt_s) ) {
		print "\nGenerating inventory for $cwdsrc\n\n";
		chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
		chdir $cwd;
		inventorize($cwdsrc,'SRC');
	}
	else {
		print "OPTS_S:$opt_s\n";
		%inventorysrc=%{retrieve( $opt_s )}; 
		print "Loading inventory from $opt_s\n";
		$cwdsrc=$inventorysrc{ "$srctag:cwd" };
		print "populated cwdsrc with: $cwdsrc\n";

		foreach $key ( keys %inventorysrc ) {
			if($key =~ /^$srctag/) {# add only srctags because file might contain both src and dst
				$inventory{ $key }=$inventorysrc{ $key };
			}
			#populate_md5(\%inventorysrc);
			if($key =~ /^$srctag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
				$md5=$inventorysrc{ $key };
				my $host=$1;
				my $dir=$2;
				my $file=$3;
				push @{ $inventorymd5{"$srctag:$md5"} }, "$host:$dir/$file";
				
			}
		}
	}
	if( !defined($opt_d) ) {
		print "\nGenerating inventory for $cwddst\n\n";
		chdir $dstdir;	 $cwddst=getcwd; #get absolute dst dir
		chdir $cwd;
		inventorize($cwddst,'DST');
	}
	else {
		print "Loading inventory from $opt_d\n";
		%inventorydst=%{retrieve( $opt_d )};
		$cwddst=$inventorydst{ "$dsttag:cwd" };
		print "populated cwddst with: $cwddst\n";
		#foreach $key ( keys %inventorydst ) {
		#	if($key =~ /^$dsttag.*:cwd/) {
		#		$cwddst=$inventorydst{ $key };
		#		print "populate cwddst with: $cwddst from key: $key\n";
		#		last;
		#	}
		#}
		foreach $key ( keys %inventorydst ) {
			if($key =~ /^$dsttag/) {
				$inventory{ $key }=$inventorydst{ $key };
			}
			#populate_md5(\%inventorydst);
			if($key =~ /^$dsttag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
				$md5=$inventorydst{ $key };
				my $host=$1;
				my $dir=$2;
				my $file=$3;
				push @{ $inventorymd5{"$dsttag:$md5"} }, "$host:$dir/$file";
			}
		}
	}
	
	print "\nMIRROR FROM $cwdsrc ---->  $cwddst\n\n";


#		print "inventory:\n",Dumper(%inventory),"\n";;
#		print "inventorymd5:\n",Dumper(%inventorymd5),"\n";


	#ginetai to compare be bash to tag poy exoun shmadeytei ta arxeia, alla xreiazetai kai to abs path giana mnporv na ta kanv move/copy.
	#telika sto compare DEN xreiazetai to abs path, giati den ginontai ekei move/copy, alla sto runactions.
	compare($cwdsrc,$srctag,$cwddst,$dsttag); 
	
	runactions($srctag,$dsttag);


}

if($opt_c eq 'ainb' ) {
	$cwd=getcwd;
	chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
	chdir $cwd; chdir $dstdir;	 $cwddst=getcwd; #get absolute dst dir
	chdir $cwd;
	print "\nGenerating inventory for $cwdsrc, $cwddst\n\n";
	#inventorize($cwdsrc,$srctag);
	#inventorize($cwddst,$dsttag);
	if( !defined($opt_s) ) {
		print "\nGenerating inventory for $cwdsrc\n\n";
		chdir $srcdir;	$cwdsrc=getcwd;              #get absolute src dir
		chdir $cwd;
		inventorize($cwdsrc,'SRC');
	}
	else {
		print "OPTS_S:$opt_s\n";
		%inventorysrc=%{retrieve( $opt_s )}; 
		print "Loading inventory from $opt_s\n";
		$cwdsrc=$inventorysrc{ "$srctag:cwd" };
		print "populated cwdsrc with: $cwdsrc\n";

		foreach $key ( keys %inventorysrc ) {
			if($key =~ /^$srctag/) {# add only srctags because file might contain both src and dst
				$inventory{ $key }=$inventorysrc{ $key };
			}
			#populate_md5(\%inventorysrc);
			if($key =~ /^$srctag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
				$md5=$inventorysrc{ $key };
				my $host=$1;
				my $dir=$2;
				my $file=$3;
				push @{ $inventorymd5{"$srctag:$md5"} }, "$host:$dir/$file";
				
			}
		}
	}
	if( !defined($opt_d) ) {
		print "\nGenerating inventory for $cwddst\n\n";
		chdir $dstdir;	 $cwddst=getcwd; #get absolute dst dir
		chdir $cwd;
		inventorize($cwddst,$dsttag);
	}
	else {
		print "Loading inventory from $opt_d\n";
		%inventorydst=%{retrieve( $opt_d )};
		$cwddst=$inventorydst{ "$dsttag:cwd" };
		print "populated cwddst with: $cwddst\n";
		#foreach $key ( keys %inventorydst ) {
		#	if($key =~ /^$dsttag.*:cwd/) {
		#		$cwddst=$inventorydst{ $key };
		#		print "populate cwddst with: $cwddst from key: $key\n";
		#		last;
		#	}
		#}
		foreach $key ( keys %inventorydst ) {
			if($key =~ /^$dsttag/) {
				$inventory{ $key }=$inventorydst{ $key };
			}
			#populate_md5(\%inventorydst);
			if($key =~ /^$dsttag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
				$md5=$inventorydst{ $key };
				my $host=$1;
				my $dir=$2;
				my $file=$3;
				push @{ $inventorymd5{"$dsttag:$md5"} }, "$host:$dir/$file";
			}
		}
	}
	
	
	
	foreach $key (keys %inventory) {
		if($key =~ /^$srctag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
			my $host=$1;
			my $dir=$2;
			my $file=$3;
			my ($sizesrc,$sizedst,$flag);
			
			$md5=$inventory{ $key };
			if( defined($inventorymd5{"$dsttag:$md5"})  ) {
				$sizesrc=$inventorymd5{"$srctag:$host:$dir/$file:size"};
				$flag=0;
				foreach my $f ($inventorymd5{"$dsttag:$md5"}) {
				# "$hostname:$reldir/$file";
					$sizedst=$inventorymd5{"$dsttag:$f:size"};
					if($sizedst==$sizesrc) { $flag=1; }
				}
				if($flag==1) { next; }
			}
			else {
				print "CMDAinB: /bin/cp $cwdsrc/$dir/$file $cwddst/\n";
			}
		}
	}

}
print "FINISHED\n";




sub compare {
	my $src=shift;
	my $srctag=shift;
	my $dst=shift;
	my $dsttag=shift;
	my ($key,$srckey,$dstkey,$newkey);
	my ($host,$hostsrc,$hostdst,$file,$dstfile,$dir,$md5,$size);

	
#sync requires many passes for the source filelist. First we want to know which files DON'T need to be touched, becuase they are the right files, in the right place.
	$hostsrc=$inventory{"$srctag:hostname"};
	$hostdst=$inventory{"$dsttag:hostname"};
	$host=$hostsrc;
# we need to run through all srcfiles
	print "first pass\n";
	foreach $key (keys %inventory) {
		if( $key!~/^$srctag:(.+):(.+)\/(.+):md5/ ) { 
			next;
		}

		$host=$1;
		$dir=$2;
		$file=$3;

		$md5=$inventory{"$srctag:$hostsrc:$dir/$file:md5"};
		$size=$inventory{"$srctag:$hostsrc:$dir/$file:size"};
		$srckey="$srctag:$hostsrc:$dir/$file";
		$dstkey="$dsttag:$hostdst:$dir/$file";
		if( $inventory{ "$srckey:md5" }  eq $inventory{ "$dstkey:md5"  } &&
		    $inventory{ "$srckey:size" } == $inventory{ "$dstkey:size" } ) {
			print "LOGpass1: $srckey: files are identical. no action needed\n";
			$inventory{ "$srctag:$hostsrc:$dir/$file:actioncmd" }="null";
			$inventory{ "$dsttag:$hostdst:$dir/$file:use" }=1; #use means that we should not touch it from now on.
			$inventory{ "$srctag:$hostsrc:$dir/$file:use" }=1;
		}
	}#foreach first pass

	
	## second pass, copy files that CANT be found anywhere on dst.
	print "second pass\n";
	foreach $key (keys %inventory) {
		# we need to keep only the the md5.
		if( $key!~/^$srctag:(.+):(.+)\/(.+):md5/ ) { 
		#	print "KEY UNMATCH: $key\n"; 
			next;
		}
		$host=$1;
		$dir=$2;
		$file=$3;

		if( $inventory{ "$srctag:$hostsrc:$dir/$file:use" } == 1 ) {
			#if this file has been proccessed, skip it
				next;
		}

		$md5=$inventory{"$srctag:$hostsrc:$dir/$file:md5"};
		$size=$inventory{"$srctag:$hostsrc:$dir/$file:size"};
		
	#we can't find a file with the same md5 at dest. we need to copy from src to dst
		if ( !defined ( $inventorymd5{"$dsttag:$md5"} ))  { 
			$inventory{ "$srctag:$hostsrc:$dir/$file:actioncmd" }="SRCcopy";
			$inventory{ "$srctag:$hostsrc:$dir/$file:actionarg" }="$dsttag:$hostdst:$cwddst/$dir/$file";
			print "LOGpass2: copying $hostsrc: $cwdsrc/$dir/$file   --> \n        $hostdst: $cwddst/$dir/$file\n";
			$inventory{ "$srctag:$hostsrc:$dir/$file:use" }=1;
		}
	}#foreach second pass
	
	
	## third pass. 
	print "third pass\n";
	foreach $key (keys %inventory) {
		# we need to keep only the the md5.
		if( $key!~/^$srctag:(.+):(.+)\/(.+):md5/ ) { 
		#	print "KEY UNMATCH: $key\n"; 
			next;
		}
		$host=$1;
		$dir=$2;
		$file=$3;

		if( $inventory{ "$srctag:$hostsrc:$dir/$file:use" } == 1 ) {
			#if this file has been proccessed, skip it
				next;
		}

		$md5=$inventory{"$srctag:$hostsrc:$dir/$file:md5"};
		$size=$inventory{"$srctag:$hostsrc:$dir/$file:size"};
		
#		print "KEY ISMATCH: $key\n\t$relsrcdir  $srcfile\n";
#		print "AAA $srctag:".$inventorymd5{"$dsttag:$md5"}[0]."    MD5: $md5\n";
		if ( defined ( $inventorymd5{"$dsttag:$md5"} ))  { #there is a file with the same md5
			my (@srcgroup,@dstgroup);
			@srcgroup=@{$inventorymd5{"$srctag:$md5"}};
			@dstgroup=@{$inventorymd5{"$dsttag:$md5"}};
			$dstfile=findbestmatch("$srctag:$hostsrc:$dir/$file",\@srcgroup,\@dstgroup);
			# env sigoura yparxei sto dst, to arxeio, mporei na exoun ginei "used" ola ta arxeia. Tote epitrefei "" to function kai prepei na kaneis copy apo to DST sto DST (kai oxi rename).
			if($dstfile eq "") {
				$dstfile=$inventorymd5{"$dsttag:$md5"}[0]; #pairnv to prvto tyxaio file apo to DST, vste na to kanv copy ekei pou prepei. den exei shmasia an einai hdh used, giati to kanv copy.
				# $dstfile has the form of: $hostdst:$dir/$file
				# $actionarg has the form of: $dsttag:$hostdst:$dir/$file
				print "LOGpass3: copying DST2DST $dstfile -->\n       $hostdst:$dir/$file\n";
				$inventory{ "$srctag:$hostsrc:$dir/$file:use" }=1;
				$inventory{ "$srctag:$hostsrc:$dir/$file:actionarg" }="$dsttag:$dstfile";
				$inventory{ "$srctag:$hostsrc:$dir/$file:actioncmd" }="DSTcopy";
			}
			else {
				print "LOGpass3: moving DST2DST $dstfile -->\n       $hostdst:$dir/$file\n";
				$inventory{ "$dsttag:$dstfile:use" }=1;
				$inventory{ "$srctag:$hostsrc:$dir/$file:use" }=1;
				$inventory{ "$srctag:$hostsrc:$dir/$file:actionarg" }="$dsttag:$dstfile";
				$inventory{ "$srctag:$hostsrc:$dir/$file:actioncmd" }="DSTmove";
			}
			
		}
	} #foreach third pass
	
} #sub compare

sub findbestmatch {
#the whole concept is that the file exists in the dst folder with another name. So we need to copy or move the files *INSIDE* DST. We don't need SRC at all
	my $srcfile=shift;
	my $arefsrc=shift;
	my $arefdst=shift;
	my ($f,$r);
	my (@srcgroup,@dstgroup);
	@srcgroup=@{ $arefsrc };
	@dstgroup=@{ $arefdst };
#	print "FINDBESTMATCH for $srcfile: \n\t\t{\n\t\t";
#	print join "\n\t\t",@srcgroup;
#	print "\n\t\t} -----> \n\t\t{\n\t\t\t\t";
#	print join "\n\t\t\t\t",@dstgroup;
#	print "\n\t\t}\n";
	$r="";
	foreach $f ( @dstgroup ) {
#		print "AAAAA $dsttag:$f:use: ".$inventory{"$dsttag:$f:use"}."\n";
		if( !defined( $inventory{"$dsttag:$f:use"} ) ) {
			$r=$f;
			last;
		}
	}
#	print "\t\t=  $r\n";
	return($r);
}


sub inventorize {
	my $dir=shift; # $dir is a clean ansolute path
	my $tag=shift;
	my ($line,$file,$reldir,$absdir,$filesize,$filewithabspath,$filemd5,$buffer,$bytesread);
	
	my $filedir;
	$inventory{"$tag:hostname"}=$hostname;
	$inventory{"$tag:cwd"}=$dir;
	open FH,"find $dir -print |";
	my $linenum=0;
	while(<FH>) {
		$line=$_; chomp $line;
		$linenum++; 
		
#		$line=~ /^(.*)\/([^\/]+)$/;
#		$file=$2; $reldir=$1;
		$filewithabspath=abs_path($line);
		$filewithabspath=~ /^$dir\/(.*)$/;
		$filedir="./$1";
		$filedir=~/(.+)\/([^\/]+)$/;
		$file=$2; $reldir=$1;
		# prepei na apallagv apo ta "./" sthn arxh kai apo thn pithanonthta na eimai sto root '/' kai na mhn kanei match to expression
		# px /lala.jpg. prepei na mpei elegxos an eina sto root
		if (-e $line) {
			if (-d $line) {
			# it is a directory
				$inventory{"$tag:$hostname:$reldir/$file:dir"}="$reldir/$file";
				next;
			}
			elsif (! -f $line) {
				print "skipping $line, because it is not a dir or a file\n";
				next;
			}
		}
		else {
			print "skipping $line, because it doesn't exist\n";
			next;
		}
		$filesize = -s $line;
		open INF,$line;
		binmode INF;
		$bytesread=read (INF, $buffer, 4000);
		$filemd5=md5_hex( $buffer);
		close INF;

#		print "$line\n\tREL  : $reldir\n\tCWD  : $cwd\n\tFILE : $file\n\tSIZE : $filesize\n\tMD5  : $filemd5($bytesread)\n";
# to path pou apothykeyetai sto hash einai to relative se sxesh me to basedir pou edvse o xrhsths. dhladh einai to path apo to basedir kai katv.		
		push @{ $inventorymd5{"$tag:$filemd5"} }, "$hostname:$reldir/$file";
		$inventory{"$tag:$hostname:$reldir/$file:md5"}=$filemd5;
		
		#$inventory{"$tag:$hostname:$reldir/$file:cwd"}=$dir;
		$inventory{"$tag:$hostname:$reldir/$file:file"}=$file;
		$inventory{"$tag:$hostname:$reldir/$file:reldir"}=$reldir;
		$inventory{"$tag:$hostname:$reldir/$file:size"}=$filesize;
		#$inventory{"$tag:$hostname:$reldir/$file:host"}=$hostname;
	}
	close FH;
}

sub runactions {
	my ($srctag,$dsttag);
	$srctag=shift;
	$dsttag=shift;
	my $key;
	my ($action,$actionarg);
	my ($host,$hostsrc,$hostdst,$file,$dir,$cwddst,$cwdsrc);
	my $safefolder;

	$hostsrc=$inventory{"$srctag:hostname"};
	$hostdst=$inventory{"$dsttag:hostname"};
	$cwdsrc=$inventory{"$srctag:cwd"};
	$cwddst=$inventory{"$dsttag:cwd"};
	
	#sbhnoume ta arxeia sto DST poy den yparxoun sto SRC kai einai unsed
	# and create directories
	my $d;
	foreach $key (keys %inventory) {
		if( $key =~ /^$srctag:$hostsrc:(.+):dir/ ) { 
			$d=$1;
			if( ! defined( $inventory{ "$dsttag:$hostdst:$d:dir" } ) ){
				print "CMDMKDIR: /bin/mkdir -p \"$1\"\n";
			}
			else {
				print "LOG: folder $d exists on DST\n";
			}
			
			# there is a problem here and it creates the '/' folder... the folder is in the inventory, so the bug resdies in inventorize
		}
		if( $key!~/^$dsttag:(.+):(.+)\/(.+):md5/ ) { 
			next;
		}
		$host=$1;
		$dir=$2;
		$file=$3;		
		if( !defined($inventory{"$dsttag:$hostdst:$dir\/$file:use"}) ) {
			if($opt_safe) {
				print "CMDDELETE: /bin/mv \"$dir\/$file\" \"$safefolder/\"\n";
			}
			else {
				print "CMDDELETE: /bin/rm \"$dir\/$file\"\n";
			}
		}
	}

	# run through all actions
	#
	my %h; #hash to keep what folders are mkdired
			
	foreach $key (keys %inventory) {
		# we need to keep only the the md5.
		if( $key!~/^$srctag:(.+):(.+)\/(.+):actioncmd/ ) { 
			next;
		}
		$host=$1;
		$dir=$2;
		$file=$3;
		
		$action=$inventory{ "$srctag:$hostsrc:$dir\/$file:actioncmd" };
		$actionarg=$inventory{ "$srctag:$hostsrc:$dir\/$file:actionarg" };
		

		# if the right file is in the right position dont do anything
		#
		if($action eq "null") {
			next;
		}
		# the right file needs to be copied from the SRC to DST
		# when hostsrc and hostdst are different, this is a two action sequence.
		elsif($action eq "SRCcopy") {
			$actionarg =~/^$dsttag:$hostdst:(.+)$/;
			$actionarg="$1";
			if( !defined($opt_i) ) {  $opt_i="intermediate-folder";  }
			if(! defined( $h{"$dir"} ) ) {
				$h{ "$dir" }=1;
				print "CMDSRCcopy1: /bin/mkdir -p \"$opt_i/$dir\"\n";
			}
			print "CMDSRCcopy1: /bin/cp \"$cwdsrc/$dir/$file\" \"$opt_i/$dir/\"\n";
			print "CMDSRCcopy2: /bin/cp \"$opt_i/$dir/$file\" \"$actionarg\"\n";
		}
		# the right file exists in DST but it can't be moved becuase it is in use. So we copy it from DST to DST
		#
		elsif($action eq "DSTcopy") {
			$actionarg=$inventory{ "$srctag:$hostsrc:$dir\/$file:actionarg" };
			$actionarg=~/^$dsttag:$hostdst:(.+)\/([^\/]+)$/;
			$actionarg="$1/$2";
			
			print "CMDDSTcopy: /bin/cp \"$actionarg\" \"$cwddst/$dir/$file\"\n";
			
		}
	}
	# the right file exists in DST and since it not used, we can just move it to the right folder with the right name. 
	#Moves are executed after possible copies, because if we move the file first, then it wont be in the right place if a copy is needed. 
	foreach $key (keys %inventory) {
		# we need to keep only the the md5.
		if( $key!~/^$srctag:(.+):(.+)\/(.+):actioncmd/ ) { 
			next;
		}
		$host=$1;
		$dir=$2;
		$file=$3;
		
		$action=$inventory{ "$srctag:$hostsrc:$dir\/$file:actioncmd" };
		if($action eq "DSTmove") {
			$actionarg=$inventory{ "$srctag:$hostsrc:$dir\/$file:actionarg" };
			$actionarg=~/^$dsttag:(.+):(.+)\/(.+)$/;
			$actionarg="$2/$3";
			#print "\tmoving $hostdst: $cwddst/$actionarg   --> \n        $hostdst: $cwddst/$dir/$file\n";
			#print "CMDMOVE: mv $cwddst/$actionarg   $cwddst/$dir/$file\n";
			print "CMDMOVE: /bin/mv \"$actionarg\"   \"$dir/$file\"\n";
		}
	}
	
}

sub print_inventory {
	my $file=shift;
	my %h;
	my $key;
	
	
	%h=%{retrieve( $file )}; 
	foreach $key (sort keys %h) {
		print "\t$key  --->  ".$h{$key}."\n";
	}
}
sub populate_md5 {
	my $h=shift;
	my ($k,$md5,$host,$dir,$file);
	
	foreach $k ( keys %{$h} ) {
		if($k =~ /^$srctag:(.+):(.+)\/(.+):md5/) {# add only srctags because file might contain both src and dst
			$md5=$h->{ $k };
			my $host=$1;
			my $dir=$2;
			my $file=$3;
			push @{ $inventorymd5{"$srctag:$md5"} }, "$host:$dir/$file";
		}
	}
}
sub printhelp {
	print "Help:\n";
	print "syncremote [--dup] [-h] [-p] [-c [gen|sync]] [-i dir] [-s srcfile] [-d dstfile] srcdir dstdir\n";
	print "Options\n";
	print "\t-h print this help file\n";
	print "\t-c command\n"; 
	print "\t\tsync   sync folders\n";
	print "\t\tgen    Generate an inventory file\n";
	print "\t\tprint  Print a generated inventory file\n";
	print "\t\tdup    find duplicates in following folders\n";
	print "\t\tAinB   find if every file in folder A, exists somewehre in folder B. Exact location, filename or number of occurences, does NOT matter\n";
	

	print "\t-i dir use intermediate directory for transfering needed files\n";
	print "\t-d flle use this file for destination files info, instead of probing actual directory\n";
	print "\t-s flle use this file for source files info, instead of probing actual directory\n";
	print "\t-p print inventory file\n";
	print "\t--dup find and print duplicates\n";
	print "\t--safe  instead of deleting setination files that don't exists in source, move them to the \"deleted\" folder\n";
	return;
}
