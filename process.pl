#!/usr/bin/perl
use strict;
use warnings;

use Cpanel::JSON::XS;
use utf8;
use Scalar::Util qw/reftype/;

use Data::Dumper;

# =============== parameters ===============

my $perek=92;

my $from_pasuk=1;
my $to_pasuk=16;

# filter of sources
my @titles=("Zohar", "Midrash Tehillim", "Yalkut Shimoni on Nach");

# font size classes based on SR (SentenceRank), length of connected meforshim
my @classes=qw/1000 4000 10000/;

# this time calculated manually from Excel
my @pasuk_class=qw/1 2 2 4 3 3 3 3 3 4 3 4 2 3 3 3/;

# =============== read relevant source filters ===============

my $header_html=`cat header.html`;
my @masechtot=split/\n/, `cat masechtot.txt`;

my %masechtot;
map { $masechtot{$_}="" } @masechtot;

my %titles;
map { $titles{$_}="" } @titles;

# =============== create index.html ===============

my $url="https://www.sefaria.org/api/texts/Psalms.$perek";

my $json=my_wget($url);
my $obj=decode_json $json;

my $text=$obj->{he};

open OUT, '>:encoding(UTF-8)', "index.html";
print OUT $header_html;
print OUT "<h1>Psalms $perek</h1>\n<p dir=\"rtl\">\n";

my $pasuk=0;
my %pasuk_text;

for my $this_pasuk (@$text) {
	my $font_class=$pasuk_class[$pasuk++];
	my $real_pasuk=$pasuk;
	
	print OUT "<span dir=\"rtl\" class=\"cl_$font_class\"><a href=\"p_$real_pasuk.html\">$this_pasuk</a></span> \n";
	$pasuk_text{$real_pasuk}=$this_pasuk;
}

print OUT "</p>\n</div>\n</body>\n</html>\n";
close OUT;

#exit;

# =============== process JSON connections of commentaries ===============

open SR, ">sr.txt";
for my $pasuk ($from_pasuk..$to_pasuk) {
	print "$pasuk\n";
	my $url="https://www.sefaria.org/api/links/Psalms.$perek.$pasuk";

	my $json=my_wget($url);
	my $obj=decode_json $json;

	my $comm_length=save_html_file("p_$pasuk.html", "Psalms $perek:$pasuk", $pasuk_text{$pasuk}, $obj);
	print SR "$pasuk $comm_length\n";
}
close SR;

# =============== functions ===============

sub my_wget {
	my $url=shift;
	
	my $ret=`wget -qO- "$url"`;
	return $ret;
}

sub save_html_file {
	my ($filename, $maintitle, $pasuk_text, $obj)=@_;	
	
	my $i=1;
	my $comm_length=0;
	
	open OUT, '>:encoding(UTF-8)', $filename;
	print OUT $header_html;
	print OUT "<h1>$maintitle</h1>\n".
		"<p dir=\"rtl\"><span class=\"cl_1\"><a href=\"index.html\">$pasuk_text</a></span></p>\n";

	# =============== filter through all connections ===============

	for my $this (@$obj) {
		my $source_ref=$this->{sourceRef};
		my $categ=$this->{category};
		my $title=$this->{collectiveTitle}->{en};
		my $text_en=$this->{text};
		my $text_he=$this->{he};

		if (reftype $text_en) {
			$text_en="";
		}
		
		# choose color scheme / filter by source type
		my $color_scheme="";
		
		if ($categ eq "Talmud" && exists $masechtot{$title}) {
			$color_scheme="gemara";
		} elsif (exists $titles{$title}) {
			if ($title eq "Zohar") {
				$color_scheme="zohar";
			} else {
				$color_scheme="midrash";
			}
		}
		
		# show commentary piece
		if ($color_scheme ne "") {
			#print "$i\t$source_ref ($categ / $title)\n";
			print OUT "<div class=\"commbox color_$color_scheme\">\n".
				"<h2>$i. $source_ref ($categ / $title)</h2>\n".
				"<p>$text_en</p>\n".
				"<p dir=\"rtl\" class=\"cl_3\">$text_he</p>\n".
				"</div>\n";
			$i++;
			$comm_length+=length($text_he);
		}
	}
	
	print OUT "</div>\n</body>\n</html>\n";
	close OUT;
	
	return $comm_length;
}







