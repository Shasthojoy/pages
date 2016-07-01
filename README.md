[![OpenCollective](https://opencollective.com/laprimaire/badge/backers.svg)](https://opencollective.com/laprimaire#support)

![democratech logo](https://democratech.co/assets/images/democratech-logo-whitebg-260x64.png)
# Pages

This is the code of LaPrimaire's [individual candidate page](https://laprimaire.org/candidat/482702054584) as well as the citizens and candidates admin page. It uses the [Sinatra](http://www.sinatrarb.com/) lightweight framework and rely on a PostgreSQL database. Pages are served through the [unicorn web server](http://unicorn.bogomips.org/).

## Usage

To install LaPrimaire's pages on your local computer, first clone the repo locally and install the dependencies:

```console
$ git clone git://github.com/democratech/pages.git
$ cd pages
$ bundle install
```
If you don't have the `bundle` command, make sure you have the latest version of ruby (`brew update && brew install ruby`) and then install the bundle command with `gem install bundler`.

Then, you need to setup your PostgreSQL database. You will need PostgreSQL 9.4 or above. If you are using Ubuntu 14.04 as your dev environment, postgresql-9.4 is not included by default so you should use [postgresql apt repository](https://www.postgresql.org/download/linux/ubuntu/) to install it easily.

Once PostgreSQL is up and running, go ahead and [create a new database role](https://www.postgresql.org/docs/9.1/static/sql-createrole.html) called 'laprimaire' and a new database called 'laprimaire_sandbox' :
```console
$ sudo -s
# su postgres
$ psql
postgres=# CREATE USER laprimaire WITH PASSWORD 'yourpassword';
postgres=# CREATE DATABASE laprimaire_sandbox;
postgres=# GRANT ALL PRIVILEGES ON laprimaire_sandbox TO laprimaire;
```

Verify you are able to connect to your newly created database :
```console
$ psql -h localhost -W -U laprimaire laprimaire_sandbox
Password for user laprimaire: 
psql (9.5.3, server 9.5.1)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

laprimaire_sandbox=>
```

Now you are ready to import the sample data that you will find in the [democratech/tools repository](https://github.com/democratech/tools/tree/master/sample_data) :
```console
$ tar xvfz laprimaire_sandbox.sql.tgz
$ psql -h localhost -W -U laprimaire laprimaire_sandbox < laprimaire_sandbox.sql
```

Check that the data has been correctly imported :
```console
$ psql -h localhost -W -U laprimaire laprimaire_sandbox
Password for user laprimaire: 
psql (9.5.3, server 9.5.1)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

laprimaire_sandbox=> \d
                     List of relations
 Schema |           Name            |   Type   |   Owner    
--------+---------------------------+----------+------------
 public | candidates                | table    | laprimaire
 public | candidates_views          | table    | laprimaire
 public | cities                    | table    | laprimaire
 public | cities_city_id_seq        | sequence | laprimaire
 public | citizens                  | table    | laprimaire
 public | countries                 | table    | laprimaire
 public | donateurs                 | table    | laprimaire
 public | donateurs_donateur_id_seq | sequence | laprimaire
 public | supporters                | table    | laprimaire
 public | toutes_candidates         | table    | laprimaire
 public | users                     | table    | laprimaire
(11 rows)

laprimaire_sandbox=>
```

With the database setup, you can copy the example configuration file and adapt it to your local settings :
```console
$ cp config/key.rb config/keys.local.rb
$ cat config/keys.local.rb
PGHOST="127.0.0.1"
PGPORT="5432" 
PGPWD="yourpassword"
PGNAME="laprimaire_sandbox"
PGUSER="laprimaire"
AWS_S3_BUCKET_URL="https://s3.eu-central-1.amazonaws.com/laprimaire/"
ABANDONS=[] # You can leave this variable as is
$ 
```
This will compile your new shining nanoc site and start watching for changes. If you don't want to use guard, you can alternatively run the following command to compile the project:
```console
$ bundle exec nanoc compile
```

Now let's start a web server to access the website locally:

```console
$ bundle exec nanoc view
```

You can now access your local copy of democratech's website at [http://localhost:3000](http://localhost:3000)

## Contributing

1. [Fork it](http://github.com/democratech/LaPrimaire/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

For development purposes, don't forget to set ```debug: true``` in the nanoc.yaml file otherwise all JS and CSS assets are concatenated and minified.

## Authors

So far, democratech's website is being developed and maintained by
* [Thibauld Favre](https://twitter.com/thibauld)
* Feel free to join us! 

## Backers

Love our work and community? Help us keep it alive by donating funds to cover project expenses!<br />
[[Become a backer](https://opencollective.com/laprimaire)]

  <a href="https://opencollective.com/laprimaire/backers/0/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/0/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/1/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/1/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/2/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/2/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/3/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/3/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/4/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/4/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/5/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/5/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/6/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/6/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/7/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/7/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/8/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/8/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/9/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/9/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/10/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/10/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/11/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/11/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/12/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/12/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/13/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/13/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/14/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/14/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/15/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/15/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/16/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/16/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/17/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/17/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/18/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/18/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/19/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/19/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/20/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/20/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/21/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/21/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/22/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/22/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/23/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/23/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/24/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/24/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/25/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/25/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/26/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/26/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/27/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/27/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/28/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/28/avatar">
  </a>
  <a href="https://opencollective.com/laprimaire/backers/29/website" target="_blank">
    <img src="https://opencollective.com/laprimaire/backers/29/avatar">
  </a>


## License

* democratech website is released under the [GNU Affero GPL](https://github.com/democratech/website/blob/master/LICENSE)
* nanoc-skeleton is released under the [MIT license](https://github.com/alessandro1997/nanoc-skeleton/blob/master/LICENSE.txt).
* nanoc is released under a [Free Software license] (https://github.com/nanoc/nanoc/blob/master/LICENSE).
* bootstrap is released under the [MIT license](https://github.com/twbs/bootstrap/blob/master/LICENSE).

