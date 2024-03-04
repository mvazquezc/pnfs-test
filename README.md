
Run:

    $ WITH_CREATE_LUN=true bash test.sh
    …
    #
    #
    rw,insecure
    #
    #
    …
    + dd if=/dev/zero of=/var/tmp/pnfs-client/data bs=1G count=1
    1+0 records in
    1+0 records out
    1073741824 bytes (1.1 GB, 1.0 GiB) copied, 6.63653 s, 162 MB/s
    …
    + grep -E 'layout|write'
    nfs v4 client layoutcommit:    11239 
    nfs v4 client    layoutget:      449 
    nfs v4 client layoutreturn:        8 
    nfs v4 client        write:    24975 
    nfs v4 servop layoutcommit:    11238 
    nfs v4 servop    layoutget:      444 
    nfs v4 servop layoutreturn:       55 
    nfs v4 servop        write:    24975 
    …
    #
    #
    pnfs,rw,insecure
    #
    #
    …
    + dd if=/dev/zero of=/var/tmp/pnfs-client/data bs=1G count=1
    1+0 records in
    1+0 records out
    1073741824 bytes (1.1 GB, 1.0 GiB) copied, 4.41001 s, 243 MB/s
    …
    + grep -E 'layout|write'
    nfs v4 client layoutcommit:    11247 
    nfs v4 client    layoutget:      451 
    nfs v4 client layoutreturn:        8 
    nfs v4 client        write:    24975 
    nfs v4 servop layoutcommit:    11246 
    nfs v4 servop    layoutget:      446 
    nfs v4 servop layoutreturn:       56 
    nfs v4 servop        write:    24975 
    …
    $
