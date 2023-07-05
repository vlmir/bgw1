#!/usr/local/bin/perl
$execute_flag_file = "listener";
$oldtime = (time + 15);
while (1) {
     if (time > $oldtime) {
         &look_for_file;
         $oldtime = (time + 15);         
     }
}

sub look_for_file () {
  if ((-e $execute_flag_file) && (-r $execute_flag_file)) {
    chdir("../pipeline") or warn "Cannot change directory: $!"; 
    system "perl -w pipeline.pl";
    chdir("../eternal") or warn "Cannot change directory: $!";
    system "mv $execute_flag_file $execute_flag_file.stop";
  }
}
