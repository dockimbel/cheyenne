#!C:\Perl\bin\perl.exe -wT
use strict;
use CGI::Carp qw(fatalsToBrowser);

print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head><title>Variables d'environnement</title></head><body>\n";
print "<h1>Variables d'environnement:</h1>\n";
print "<table border=\"1\">\n";
print "<tr><th align=\"left\" bgcolor=\"#E0E0E0\">Nom de variable</th>",
      "<th align=\"left\" bgcolor=\"#E0E0E0\">Valeur</th></tr>\n";
foreach(keys(%ENV)) {
  print "<tr><td><b>$_</b></td><td><tt>$ENV{$_}</tt></td></tr>\n";
}
print "<tr><th align=\"left\" bgcolor=\"#E0E0E0\" colspan=\"2\">au total: ",
      scalar keys(%ENV)," variables d'environnement</th></tr>\n";
print "</table>\n";
print "</body></html>\n";