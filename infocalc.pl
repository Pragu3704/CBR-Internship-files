###########################################
### Initialize and read in command-line ###
###########################################

$badconst = -9999;

use Getopt::Long;
my %opts = (column => 3, numpops => 2, input => "infile", output => "outfile", weightfile => "[none]");
Getopt::Long::GetOptions( \%opts, qw(
  column=i
  input=s
  numpops=i
  output=s
  weightfile=s
)) || die "Exiting... failed to parse command-line options\n";

if ($opts{column}<=0 || $opts{column}>5) 
  {die "Exiting... column specifying population identifiers (-column) must be in [1,5]\n";}
if ($opts{numpops}<=0) 
  {die "Exiting... number of populations (-numpops) must be a positive integer\n";}

$column  = $opts{column}-1;
$numPops = $opts{numpops};
$sample  = $opts{input};
$outfile = $opts{output};
$wfile   = $opts{weightfile};

open (OUTFI, ">$outfile") || die ("Exiting... can't open output file (-output) $outfile");

##########################################
### Read in file of population weights ###
##########################################

if ($wfile ne "[none]") {
  open (WEIGHTFI, $wfile) || die ("Exiting... can't open file of weights (-weightfile) $wfile");
  $sum=0;
  while ($line = <WEIGHTFI>) {
    chomp($line);
    @fields = split(/\s+/, $line);
    if ($#fields != 1) {die ("Exiting... weightfile $wfile does not have exactly two columns");}
    $pop = $fields[0];
    $weight{$pop} = $fields[1];
    $sum+=$weight{$pop};
  }
  if ( ($sum-1)*($sum-1) > 0.000001) {
    die ("Exiting... sum of weights in weightfile $wfile is not 1\n");
  }
}

#######################################################
### Read in list of loci from top line of data file ###
#######################################################

open (DATAFILE, $sample) || die ("Exiting... can't open input data file (-input) $sample");
$line = <DATAFILE>;
chomp($line);
@loci = split(/\s+/, $line);

##################################################################
### Read in data, obtain absolute frequencies and sample sizes ###
##################################################################

while ($line = <DATAFILE>) {
  chomp($line);
  @fields = split(/\s+/, $line);
  $pop = $fields[$column];
  if ($wfile eq "[none]") {$weight{$pop} = 1/$numPops;}
  $totalcount{$pop}+=0.5;
  for $i (5 .. $#fields) {
    $locus = $loci[$i-5];
    if ($fields[$i] > 0) {
      $allele = $fields[$i];
      ${${$absfreq{$locus}}{$allele}}{$pop}++;
      ${$sampsize{$locus}}{$pop}++;
    }
  }  
}

############################
### Perform a few checks ###
############################

$sum=0;
$num=0;
foreach $pop (keys %totalcount) {
  $sum+=$weight{$pop};
  if ($weight{$pop} < 0 || $weight{$pop} >= 1) {
    die ("Exiting... weight for population $pop is outside the range [0,1)\n");
  }
    $num++;
}  
if ($num != $numPops) {
  print ("Exiting... number of populations detected is not the same as in -numpops.\n");
  print ("  (1) Check that -numpops reflects the correct number of\n");
  print ("      populations in the appropriate column of the data file.\n");
  die   ("  (2) Check that the correct column was specified in -column.\n");
}
if ( ($sum-1)*($sum-1) > 0.000001) {
  print ("Exiting... the sum of population weights in the data file is not 1.\n");
  print ("  (1) Check that -numpops reflects the correct number of\n");
  print ("      populations in the appropriate column of the data file.\n");
  print ("  (2) Check that the correct column was specified in -column.\n");
  print ("  (3) If you are using a weightfile, check that the spelling \n");
  print ("      of population names is the same in the weightfile as in \n");
  die   ("      the data file.\n");
}
if ($numPops>24) { 
  {print "Warning: number of populations (-numpops) must be at most 24.\n";}
  {print "---> The computation of I_a will be omitted.\n";}
}

#####################################################################
### Compute relative frequencies for each locus-allele-population ###
### combination, and average frequencies across populations.      ###
#####################################################################

foreach $locus (keys %absfreq) {
  foreach $allele (keys %{$absfreq{$locus}}) {
    $aver = 0;
    foreach $pop (keys %{${$absfreq{$locus}}{$allele}}) {
      $r = ${${$absfreq{$locus}}{$allele}}{$pop}; 
      $s = ${$sampsize{$locus}}{$pop};
      ${${$relfreq{$locus}}{$allele}}{$pop} = $r / $s;
      $aver += $weight{$pop} * ${${$relfreq{$locus}}{$allele}}{$pop};
    }
    ${$averageRelfreq{$locus}}{$allele} = $aver;
  }
}

####################################################
### Compute informativeness for assignment (I_n) ###
####################################################

foreach $locus (keys %absfreq) {
  $left = 0;
  $right = 0;
  foreach $allele (keys %{$absfreq{$locus}}) {
    $pj = ${$averageRelfreq{$locus}}{$allele};
    if ($pj > 0) {$left -= $pj * log($pj)};
  }
  foreach $allele (keys %{$absfreq{$locus}}) {
    foreach $pop (keys %{${$absfreq{$locus}}{$allele}}) {   
      $pij = ${${$relfreq{$locus}}{$allele}}{$pop};
      if ($pij > 0) { $right += $weight{$pop} * $pij * log($pij); }
    }
  }
  $mutualinfo{$locus} = $left + $right;
}

############################################
### Compute ORCA (single-allele version) ###
############################################

foreach $locus (keys %absfreq) {
  $decisioninfo{$locus} = 0;
  foreach $allele (keys %{$absfreq{$locus}}) {
    $maxpijqi = 0;
    foreach $pop (keys %{${$absfreq{$locus}}{$allele}}) {   
      $pijqi = ${${$relfreq{$locus}}{$allele}}{$pop} * $weight{$pop};
      if ($pijqi > $maxpijqi) { $maxpijqi = $pijqi; }
    }
    $decisioninfo{$locus} += $maxpijqi;
  }
}

###############################################
### Compute ORCA (diploid genotype version) ###
###############################################

foreach $locus (keys %absfreq) {
  $dipldecisioninfo{$locus} = 0;
  foreach $allele (keys %{$absfreq{$locus}}) {
    foreach $otherallele (keys %{$absfreq{$locus}}) {
      $maxprod = 0;
      foreach $pop (keys %{${$absfreq{$locus}}{$allele}}) {   
        $prod  = ${${$relfreq{$locus}}{$allele}}{$pop} * $weight{$pop};
        $prod *= ${${$relfreq{$locus}}{$otherallele}}{$pop};
        if ($prod > $maxprod) { $maxprod = $prod; }
      }
      $dipldecisioninfo{$locus} += $maxprod;
    }
  }
}

##########################
### Compute factorials ###
##########################

BEGIN {
  my @fact = (1);
  sub factorial($) {
    my $n = shift;
    return $fact[$n] if defined $fact[$n];
    $fact[$n] = $n * factorial($n - 1);
  }
}

######################################
### List Stirling number constants ###
######################################

sub stirling {
  if ($numPops == 2) { return 3 };
  if ($numPops == 3) { return 11 };
  if ($numPops == 4) { return 50 };
  if ($numPops == 5) { return 274 };
  if ($numPops == 6) { return 1764 };
  if ($numPops == 7) { return 13068 };
  if ($numPops == 8) { return 109584 };
  if ($numPops == 9) { return 1026576 };
  if ($numPops == 10) { return 10628640 };
  if ($numPops == 11) { return 120543840 };
  if ($numPops == 12) { return 1486442880 };
  if ($numPops == 13) { return 19802759040 };
  if ($numPops == 14) { return 283465647360 };
  if ($numPops == 15) { return 4339163001600 };
  if ($numPops == 16) { return 70734282393600 };
  if ($numPops == 17) { return 1223405590579200 };
  if ($numPops == 18) { return 22376988058521600 };
  if ($numPops == 19) { return 431565146817638400 };
  if ($numPops == 20) { return 8752948036761600000 };
  if ($numPops == 21) { return 186244810780170240000 };
  if ($numPops == 22) { return 4148476779335454720000 };
  if ($numPops == 23) { return 96538966652493066240000 };
  if ($numPops == 24) { return 2342787216398718566400000 };
}

################################################
### Check if ok to compute I_a               ###
###   -need at most 24 populations           ###
###   -population weights need to be uniform ###
################################################

$computeIa=1;
if ($numPops > 24) {$computeIa=0;}
foreach $pop (keys %totalcount) {
  if ($weight{$pop} * $numPops != 1) {$computeIa=0;}
}

###############################################################
### Compute informativeness for ancestry coefficients (I_a) ###
###############################################################

if ($computeIa == 1) {
  $stirl = stirling($numPops);
  $facto = factorial($numPops);
  foreach $locus (keys %absfreq) {
    $sum = 0;
    foreach $allele (keys %{$absfreq{$locus}}) {
      $pj = ${$averageRelfreq{$locus}}{$allele};
      $sum += $pj * (1 - log($pj) - $stirl/$facto ); 
      foreach $pop (keys %{${$absfreq{$locus}}{$allele}}) {   
        $pij = ${${$relfreq{$locus}}{$allele}}{$pop};
        $num = 0;
        $denom = $numPops;
        if ($pij > 0) { 
          $num = ($pij ** $numPops) * log($pij);
          $z = 0;
          foreach $otherpop (keys %{${$absfreq{$locus}}{$allele}}) {   
            if ($otherpop ne $pop) {
              $plj = ${${$relfreq{$locus}}{$allele}}{$otherpop};
              $denom *= $pij - $plj;
            }
            $z++;
          }
          while ($z < $numPops) {
            $denom *= $pij;
            $z++;
          }
          if ($denom != 0 && $sum != $badconst) {
            $sum += $num/$denom;
          }
          if ($denom == 0) { 
            $sum = $badconst;
          }
        }
      }
    }
    $ancestryinfo{$locus} = $sum;
  }
}

############################
### Print the statistics ###
############################

printf OUTFI ("%10s\t%10s\t%10s\t", "Locus", "I_n", "I_a");
printf OUTFI ("ORCA[1-allele]\tORCA[2-allele]\n");
foreach $locus (sort keys %absfreq) {
  printf OUTFI ("%10s\t%10g\t", $locus, $mutualinfo{$locus});
  if ($computeIa==1) {printf OUTFI ("%10g\t", $ancestryinfo{$locus})};
  if ($computeIa==0) {printf OUTFI ("%10s\t", "NA")};
  printf OUTFI ("%10g\t", $decisioninfo{$locus});
  printf OUTFI ("%10g\n", $dipldecisioninfo{$locus});
}

########################################################
### Print summary of command line to the output file ###
########################################################

printf OUTFI "Command:       ";
printf OUTFI "infocalc  -column $opts{column}  ";
printf OUTFI "-numpops $opts{numpops}  ";
printf OUTFI "-input $opts{input}  ";
printf OUTFI "-output $opts{output}  ";
printf OUTFI "-weightfile $opts{weightfile}\n";

#################################################
### Print the weights used in the calculation ###
#################################################

printf OUTFI ("PriorWeights:  ");
foreach $pop (sort keys %totalcount) {
  printf OUTFI ("%s %g   ", $pop, $weight{$pop});
} printf OUTFI ("\n");


#################################################
#################################################
#################################################
#
