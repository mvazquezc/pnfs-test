FROM fedora:40

RUN dnf install -y nfs-utils targetcli sg3_utils

# Configure NFS
RUN nfsconf --set exportd debug all
RUN nfsconf --set mountd debug all

RUN nfsconf --set nfsd debug 1
RUN nfsconf --set nfsd vers3 n
RUN nfsconf --set nfsd vers4 y
RUN nfsconf --set nfsd vers 4.1 y
RUN nfsconf --set nfsd vers 4.2 y
RUN nfsconf --set nfsd rdma n
RUN nfsconf --dump

ADD contrib/main.sh /app/

ENTRYPOINT /app/main.sh
