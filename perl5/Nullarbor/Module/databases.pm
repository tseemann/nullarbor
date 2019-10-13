package Nullarbor::Module::databases;
use Moo;
extends 'Nullarbor::Module';

use File::stat;
use File::Which;
use File::Basename;
use Cwd qw(realpath);
use Nullarbor::Logger qw(msg err);
use Time::Piece;

#...........................................................................................

sub name {
  return "Databases";
}

#...........................................................................................

sub get_makefile_var {
  my($self, $var) = @_;
  open my $MF, '<', $self->indir . '/Makefile';
  my($line) = grep { m/^$var\b/ } <$MF>;
  close $MF;
  chomp $line;
  $line =~ s/^.*?\s*:=\s*//g;
  return $line;
}

#...........................................................................................

sub _file_date {
  my($fname) = @_;
  my $s = stat($fname) or return 'not available';;
  my $t = localtime($s->mtime);
  return $t->ymd;
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  
  my @inv = ( [ "Database", "Name", "Date" ] );
 
  # the fact that I need to hack this out of the Makefile
  # embarrases me; but not enough to make me refactor the
  # whole pipeline. well not yet, anyway.
 
  my $tax = $self->get_makefile_var('TAXONER');
  ($tax) = $tax =~ m{/(\w+)\.sh$};
  my $taxdb = $ENV{ uc($tax)."_DEFAULT_DB" };
  push @inv, [ "Taxoner($tax)", $taxdb, _file_date($taxdb) ];
  
  my $abrdb = realpath(dirname(which('abricate'))."/../db");
  
  my $res = $self->get_makefile_var('RESISTOME_DB');
  my $resfn = "$abrdb/$res/sequences";
  push @inv, [ 'Resistome', $resfn, _file_date($resfn) ];
  
  my $vir = $self->get_makefile_var('VIRULOME_DB');
  my $virfn = "$abrdb/$vir/sequences";
  push @inv, [ 'Virulome', $virfn, _file_date($virfn) ];

  my $mlst = realpath(dirname(which('mlst'))."/../db/blast/mlst.fa");
  push @inv, [ 'MLST', $mlst, _file_date($mlst) ];
  
  return $self->matrix_to_html(\@inv, 1);
}

#...........................................................................................

1;
