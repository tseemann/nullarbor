package Nullarbor::Module::databases;
use Moo;
extends 'Nullarbor::Module';

use File::stat;
use Cwd qw(realpath);
use Nullarbor::Logger qw(msg err);
use Time::Piece;

#...........................................................................................

sub name {
  return "Databases";
}

#...........................................................................................

sub file_date {
  my($fname) = @_;
  my $s = stat($fname);
  my $t = localtime($s->mtime);
  return $t->ymd;
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  
  my @inv = ( [ "Database", "Name", "Date" ] );
 
  # Kraken
  my $db = $ENV{KRAKEN_DEFAULT_DB};
  -d $db or err("Can't read Kraken database folder '$db'");
  $db = realpath($db);
  push @inv, [ 'Kraken', $db, file_date("$db/database.kdb") ];

  # mlst
  my($m) = qx(mlst --help | grep -- --blastdb);
  $m =~ m/default\s+'(.*?)'/ or err("Could not parse: $m");
  $db = realpath($1);
  push @inv, [ 'mlst', $db, file_date($db) ];
  
  # resistome
  
  # virulome
  
  return $self->matrix_to_html(\@inv, 1);
}

#...........................................................................................

1;
