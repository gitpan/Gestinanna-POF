use Test::More tests => 1;

use File::Path;

rmtree 'alzabo';

unlink 'gst_pof_test_alzabo_schema';

ok(1);
