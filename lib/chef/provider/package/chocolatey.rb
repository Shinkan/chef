#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/package'
require 'chef/resource/chocolatey_package'
require 'chef/mixin/powershell_out'

class Chef
  class Provider
    class Package
      class Chocolatey < Chef::Provider::Package
        include Chef::Mixin::PowershellOut

        provides :chocolatey_package, os: "windows"

        package_class_supports_arrays

        def load_current_resource
          current_resource = Chef::Resource::ChocolateyPackage.new(new_resource.name)
          current_resource.package_name(new_resource.package_name)
          current_resource.version(build_current_versions)
          populate_candiate_versions
          current_resource
        end

        def define_resource_requirements
          super

          requirements.assert(:all_actions) do |a|
            a.assertion { !new_resource.source }
            a.failure_message(Chef::Exceptions::Package, 'chocolatey package provider cannot handle source attribute.')
          end
        end

        def install_package(name, version)
          name_versions = name_array.zip(version_array)

          name_nil_versions = name_versions.select { |n,v| v.nil? }
          name_has_versions = name_versions.reject { |n,v| v.nil? }

          # choco does not support installing multiple packages with version pins
          name_has_versions.each do |name, version|
            shell_out!("#{choco_exe} install -y -version #{version} #{cmd_args} #{name}"
          end

          # but we can do all the ones without version pins at once
          unless name_nil_versions.empty?
            names = name_nil_versions.keys.join(' ')
            shell_out!("#{choco_exe} install -y #{cmd_args} #{names}"
          end
        end

        def upgrade_package(name, version)
          unless version.all? { |n,v| v.nil? }
            raise Chef::Exceptions::Package, "Chocolatey Provider does not support version pins on upgrade command, use install instead"
          end

          names = name.join(' ')
          shell_out!("#{choco_exe} upgrade -y #{cmd_args} #{names}"
        end

        def remove_package(name, version)
          names = name.join(' ')
          shell_out!("#{choco_exe} uninstall -y #{cmd_args} #{names}"
        end

        def purge_package(name, version)
          remove_package(name, version)
        end

        private

        def choco_exe
          @choco_exe ||=
            File.join(
              powershell_out!(
                "[System.Environment]::GetEnvironmentVariable('ChocolateyInstall', 'MACHINE')"
              ).stdout.chomp,
              'bin',
              'choco.exe'
          )
        end

        def populate_candidate_versions
          if new_resource.name.is_a?(Array)
            # FIXME: superclass should be made smart enough so that when we declare
            # package_class_supports_arrays, then it accepts current_resource.version as an
            # array when new_resource.name is not
            new_resource.name.map do |name|
              self.class.available_packages[name]
            end
          else
            self.class.available_packages[new_resource.name]
          end
        end

        def build_current_versions
          if new_resource.name.is_a?(Array)
            # FIXME: superclass should be made smart enough so that when we declare
            # package_class_supports_arrays, then it accepts current_resource.version as an
            # array when new_resource.name is not
            new_resource.name.map do |name|
              installed_packages[name]
            end
          else
            installed_packages[new_resource.name]
          end
        end

        def cmd_args
          new_resource.options || ""
        end

        def self.available_packages
          @available_packages ||= parse_list_output("#{choco_exe} list -r")
        end

        def installed_packages
          @installed_packages ||= parse_list_output("#{choco_exe} list -l -r")
        end

        def self.parse_list_output(cmd)
          hash = {}
          shell_out!(cmd).stdout.each_line do |line|
            name, version = line.split('|')
            hash[name] = version
          end
          hash
        end
      end
    end
  end
end