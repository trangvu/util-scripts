#!/usr/bin/perl

#
# What's this?
# ------------
#
# Given a CSV-format manual evaluation file created by syseval-combine.pl,
# this script restores the orders of the systems and calculates an average
# score for each system.
#
# Usage and Data Format
# ---------------------
#
# syseval-report.pl finished-eval.csv output.ids
#
# Where finished-eval is a completely filled in manual evaluation CSV file
# and output.ids is the ID file output by syseval-combine.pl
#
# TODO: Add significance tests to the report

use strict;
use warnings;
use utf8;
use Getopt::Long;
use List::Util qw(sum min max shuffle);
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $LINES = -1;
my $COMPS = "0-1";
GetOptions(
    "lines=i" => \$LINES,
    "comps=s" => \$COMPS,
);

if(@ARGV != 2) {
    print STDERR "Usage: $0 TSV IDS\n";
    exit 1;
}
open FILE0, "<:utf8", $ARGV[0] or die "Couldn't open $ARGV[0]\n";
open FILE1, "<:utf8", $ARGV[1] or die "Couldn't open $ARGV[1]\n";

my ($stsv, $sids, $lines, @scores, @tsvs, @vals, @refs, $header);
while(($stsv = <FILE0>) and ($sids = <FILE1>)) {
    if((not $header) and ($stsv =~ /^(Source|Reference)\t/)) {
        $header = 1; $stsv = <FILE0>;
    }
    ++$lines;
    last if ($LINES != -1) and ($lines > $LINES);
    chomp $stsv; chomp $sids;
    push @tsvs, $stsv;
    my @atsv = split(/\t/, $stsv);
    my @aids = split(/\t/, $sids);
    $refs[$lines-1] = shift(@atsv);
    $refs[$lines-1] .= "\t".shift(@atsv) if(@atsv % 2 == 1);
    if((max(@aids)+1)*2 != @atsv) { die "MISMATCHED LINES:\n$stsv\n$sids\n"; }
    foreach my $i (0 .. $#aids) {
        $scores[$i] = [] if not $scores[$i];
        $atsv[$aids[$i]*2+1] =~ /^[0-9\.]+$/ or die "Unfinished line $stsv\n";
        push @{$scores[$i]}, $atsv[$aids[$i]*2+1];
        $vals[$i] = [] if not $vals[$i];
        push @{$vals[$i]}, $atsv[$aids[$i]*2];
    }
}

# for(split(/,/, $COMPS)) {
#    my ($base, $sys) = split(/-/);
# }

foreach my $i (1 .. scalar(@{$scores[0]})) {
    my @line = ($i, (map { $scores[$_]->[$i-1] } (0 .. $#scores)), (map { $vals[$_]->[$i-1] } (0 .. $#vals)), $refs[$i-1]);
    print join("\t", @line)."\n";
}
my @avgscores = map { sum(@$_) / $lines } @scores;
print join("\t", "Total", @avgscores)."\n";
foreach my $i (0 .. $#avgscores-1) {
    foreach my $j ($i+1 .. $#avgscores) {
        my ($w, $t, $l) = bootstrap($scores[$i], $scores[$j]);
        print "$i-vs.-$j\t$w\t$t\t$l\n";
    }
}

# Perform bootstrap resampling to estimate probabilities
sub bootstrap {
    my $ITER = 10000;
    my @sysa = @{shift(@_)};
    my @sysb = @{shift(@_)};
    @sysa == @sysb or die "Uneven numbers of scores";
    my @ids = (0 .. $#sysa);
    my @wins = (0, 0, 0);
    for(1 .. $ITER) {
        @ids = shuffle(@ids);
        my ($sa, $sb);
        for(@ids[0 .. int(@ids/2)]) {
            $sa += $sysa[$_];
            $sb += $sysb[$_];
            # print "$sysa[$_] $sysb[$_]\n";
        }
        if($sa > $sb) { $wins[0]++; }
        elsif($sb > $sa) { $wins[2]++; }
        else { $wins[1]++; }
    }
    return map { $_ / $ITER } @wins;
}
