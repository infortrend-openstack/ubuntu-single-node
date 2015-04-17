## this script handle up-to-date driver to run on Juno environment
# Juno <=> Kilo
# from cinder.openstack.common import log as logging <=> from oslo_log import log as logging
# from oslo.config import cfg <=> from oslo_config import cfg
# from cinder.openstack.common import timeutils <=> from oslo_utils import timeutils
# from cinder.openstack.common import processutils <=> from oslo_concurrency import processutils

echo "Please Enter Driver Path:"
read driver_dir
if [[ "$driver_dir" == "" ]]; then
    echo "Set default path /usr/lib/python2.7/dist-packages/cinder/volume/drivers/"
    driver_dir=/usr/lib/python2.7/dist-packages/cinder/volume/drivers/
fi

cd $driver_dir/infortrend
find -name "*.py" | xargs -i sed -i "s/from oslo_log import log as logging/from cinder.openstack.common import log as loggin/g" {}
find -name "*.py" | xargs -i sed -i "s/from oslo_config import cfg/from oslo.config import cfg/g" {}
find -name "*.py" | xargs -i sed -i "s/from oslo_utils import timeutils/from cinder.openstack.common import timeutils/g" {}
find -name "*.py" | xargs -i sed -i "s/from oslo_concurrency import processutils/from cinder.openstack.common import processutils/g" {}
cd -
