use strict;
use Cwd;
use IO::Handle;

STDOUT->autoflush(1);

my $out = $ENV{"out"};
mkdir "$out", 0755 || die "error creating $out";


my $symlinks = 0;

my %priorities;


# For each activated package, create symlinks.

sub createLinks {
    my $srcDir = shift;
    my $dstDir = shift;
    my $priority = shift;

    my @srcFiles = glob("$srcDir/*");

    foreach my $srcFile (@srcFiles) {
        my $baseName = $srcFile;
        $baseName =~ s/^.*\///g; # strip directory
        my $dstFile = "$dstDir/$baseName";

        # The files below are special-cased so that they don't show up
        # in user profiles, either because they are useless, or
        # because they would cause pointless collisions (e.g., each
        # Python package brings its own
        # `$out/lib/pythonX.Y/site-packages/easy-install.pth'.)
        # Urgh, hacky...
        if ($srcFile =~ /\/propagated-build-inputs$/ ||
            $srcFile =~ /\/nix-support$/ ||
            $srcFile =~ /\/perllocal.pod$/ ||
            $srcFile =~ /\/easy-install.pth$/ ||
            $srcFile =~ /\/site.py$/ ||
            $srcFile =~ /\/site.pyc$/ ||
            $srcFile =~ /\/info\/dir$/ ||
            $srcFile =~ /\/log$/)
        {
            # Do nothing.
	}

        elsif (-d $srcFile) {

            lstat $dstFile;
            
            if (-d _) {
                createLinks($srcFile, $dstFile, $priority);
            }

            elsif (-l _) {
                my $target = readlink $dstFile or die;
                if (!-d $target) {
                    die "collission between directory `$srcFile' and non-directory `$target'";
                }
                unlink $dstFile or die "error unlinking `$dstFile': $!";
                mkdir $dstFile, 0755 || 
                    die "error creating directory `$dstFile': $!";
                createLinks($target, $dstFile, $priorities{$dstFile});
                createLinks($srcFile, $dstFile, $priority);
            }

            else {
                symlink($srcFile, $dstFile) ||
                    die "error creating link `$dstFile': $!";
                $priorities{$dstFile} = $priority;
                $symlinks++;
            }
        }

        else {

            if (-l $dstFile) {
                my $target = readlink $dstFile;
                my $prevPriority = $priorities{$dstFile};
                die ( "Collission between `$srcFile' and `$target'. "
                    . "Suggested solution: use `nix-env --set-flag "
                    . "priority NUMBER PKGNAME' to change the priority of "
                    . "one of the conflicting packages.\n" )
                    if $prevPriority == $priority;
                next if $prevPriority < $priority;
                unlink $dstFile or die;
            }
            
            symlink($srcFile, $dstFile) ||
                die "error creating link `$dstFile': $!";
            $priorities{$dstFile} = $priority;
            $symlinks++;
        }
    }
}


my %done;
my %postponed;

sub addPkg;
sub addPkg {
    my $pkgDir = shift;
    my $priority = shift;

    return if (defined $done{$pkgDir});
    $done{$pkgDir} = 1;

#    print "symlinking $pkgDir\n";
    createLinks("$pkgDir", "$out", $priority);

    my $propagatedFN = "$pkgDir/nix-support/propagated-user-env-packages";
    if (-e $propagatedFN) {
        open PROP, "<$propagatedFN" or die;
        my $propagated = <PROP>;
        close PROP;
        my @propagated = split ' ', $propagated;
        foreach my $p (@propagated) {
            $postponed{$p} = 1 unless defined $done{$p};
        }
    }
}


# Convert the stuff we get from the environment back into a coherent
# data type.
my @paths = split ' ', $ENV{"paths"};
my @active = split ' ', $ENV{"active"};
my @priority = split ' ', $ENV{"priority"};

die if scalar @paths != scalar @active;
die if scalar @paths != scalar @priority;

my %pkgs;

for (my $n = 0; $n < scalar @paths; $n++) {
    $pkgs{$paths[$n]} =
        { active => $active[$n]
        , priority => $priority[$n] };
}


# Symlink to the packages that have been installed explicitly by the
# user.
foreach my $pkg (sort (keys %pkgs)) {
    #print $pkg, " ", $pkgs{$pkg}->{priority}, "\n";
    addPkg($pkg, $pkgs{$pkg}->{priority}) if $pkgs{$pkg}->{active} ne "false";
}


# Symlink to the packages that have been "propagated" by packages
# installed by the user (i.e., package X declares that it want Y
# installed as well).  We do these later because they have a lower
# priority in case of collisions.
my $priorityCounter = 1000; # don't care about collisions
while (scalar(keys %postponed) > 0) {
    my @pkgDirs = keys %postponed;
    %postponed = ();
    foreach my $pkgDir (sort @pkgDirs) {
        addPkg($pkgDir, $priorityCounter++);
    }
}


print STDERR "created $symlinks symlinks in user environment\n";


symlink($ENV{"manifest"}, "$out/manifest.nix") or die "cannot create manifest";
