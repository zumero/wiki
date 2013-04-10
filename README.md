# Zumero iOS wiki sample app

## Setting up the app

If you haven't already created a Zumero account, you'll want to do that.
Instructions can be found at [zumero.com](http://zumero.com/get-started/).

If you're using this project from within the
[Zumero SDK](http://zumero.com/dev-center/), you should have everything you
need.  

If you've pulled this code down separately, you'll want to download the SDK
and extract the `Zumero.framework` section.  The wiki Xcode project expects 
that framework to live two directories below the project root, 
i.e. at `../../Zumero.framework`

You'll need to tell the app where, and how, to sync your changes. Since the
app attempts to create its own database tables, you'll need to use an account
with sufficient permissions.  If the database already exists on the server 
(e.g. if another copy of the app has already uploaded some data),
you'll need an account with permission to add and modify rows.

## Adding Users and Rights to your Server's Database

For simplicity's sake, let's create a `wikiauth` database full of users,
and tell the server that any authenticated user can add wiki pages, edit them,
and sync.  See the "Internal Auth" section of 
["SQLite Development with Zumero"](http://zumero.com/docs/zumero_core.html)
for more details on managing authentication and permissions.

Make sure you have a SQLite shell with `.load` enabled -- see
[Getting Started](http://zumero.com/docs/getting_started.html) for details.

From a .load-enabled SQLite shell, load the Zumero client library:

    $ path/to/sqlite3
    sqlite> .load path/to/zumero.dylib
  
And we'll create the `wikiauth` file, authenticating ourselves as the admin
user created along with your Zumero account.

    sqlite> select zumero_internal_auth_create(
      'https://yourserver.s.zumero.net',
      'wikiauth',                          -- our new auth DB
      zumero_internal_auth_scheme('zumero_users_admin'),
      'admin', 'youradminpassword',

      NULL, NULL,                          -- don't create a user yet

      -- but anyone can do so later
      '', zumero_named_constant('acl_who_anyone'),
    
      -- only admins can add ACLs
      zumero_internal_auth_scheme('zumero_users_admin'),
      zumero_named_constant('acl_who_specific_user') || 'admin');

We're saying "let anyone add users to this table", to simplify this:

    sqlite> select zumero_internal_auth_add_user(
      'https://yourserver.s.zumero.net',
      'wikiauth',
      NULL, NULL, NULL,                    -- no auth needed
      'wikiuser', 'wikipassword');         -- new user's credentials

Now we'll tell the server that `wikiuser` (and other users authenticated
via `wikiauth`) may create and modifiy databases.  We want to be `admin`
for this.

    # sync a copy of zumero_config to memory
    $ path/to/sqlite3 :memory:
    sqlite> .load path/to/zumero.dylib
    select zumero_sync(
      'main',
      'https://yourserver.s.zumero.net',
      'zumero_config',
      zumero_internal_auth_scheme('zumero_users_admin'),
      'admin', 'youradminpassword');
    
    -- any wikiauth user can create and modify dbfiles
    INSERT INTO z_acl (scheme,who,tbl,op,result) VALUES (
      zumero_internal_auth_scheme('wikiauth'),
      zumero_named_constant('acl_who_any_authenticated_user'), 
      '',    
      '*', 
      zumero_named_constant('acl_result_allow'));
    
    -- and sync our changes back to the server
    select zumero_sync(
      'main',
      'https://yourserver.s.zumero.net',
      'zumero_config',
      zumero_internal_auth_scheme('zumero_users_admin'),
      'admin', 'youradminpassword');


## Update the App's Configuration

In Xcode, edit `ZWConfig.m` to reflect your Zumero server's URL, and the username/password we've created.

	+ (NSString *)server
	{
		return @"https://yourserverhere.s.zumero.net";
	}
    
	+ (NSString *)username
	{
		return @"wikiuser";
	}
    
	+ (NSString *)password
	{
		return @"wikipassword";
	}

When initially testing your setup, you may find it helpful to have the app report sync
failures.  Uncomment this line in `ZWAppDelegate::syncFail`:

    //	[ZWError reportError:@"sync failed" description:@"Zumero sync failed" error:err];


## Run the App

Your page list will initially be empty.  Tap the add ("+") button to add a new page; edit its title
and text (in Markdown format) and tap "Done" to save the page.

The "History" button lets you list previous versions of a page; selecting one of those versions
to view it.  Historical versions of pages are not editable.

Every few minutes (or whenever you add or modify a page), the app will sync
with your Zumero server in the background.  
