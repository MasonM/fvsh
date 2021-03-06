module Avsh
  # Encapsulates parsed config details from VagrantfileEnvironment
  class ParsedConfig
    attr_reader :primary_machine

    # @param vagrantfile_dir [String] The directory containing the Vagrantfile
    # (used for synced folder path expansion with relative directories).
    # @param global_synced_folders [Hash] The globally-defined synced folders,
    #   with keys being the guest directory (destination) and values being the
    #   host directory (source).
    # @param machine_synced_folders [Hash] Hash of machine names to a hash of
    #   synced folders defined in that machine definition (potentially empty)
    # @param primary_machine [String] The name of the primary machine, if one
    #   was defined
    def initialize(vagrantfile_dir, global_synced_folders,
                   machine_synced_folders, primary_machine)
      @vagrantfile_dir = vagrantfile_dir
      @global_synced_folders = global_synced_folders.freeze
      @machine_synced_folders = machine_synced_folders.freeze
      @primary_machine = primary_machine
    end

    # Returns the machines that match the given search string, raising an
    # exception if no matches are found.
    # Partially based off https://github.com/mitchellh/vagrant/blob/85f1e05e2a9bf7a7940bb4498472b809ba43e01f/lib/vagrant/plugin/v2/command.rb#L183
    def match_machines!(search_string)
      machines =
        if (pattern = search_string[%r{^/(.+?)/$}, 1])
          match_machines_by_regexp(pattern)
        elsif search_string.include? ','
          # Recursively call this function to match all machines in the list,
          # raising an exception if any could not be found
          search_string.split(',')
                       .map! { |s| match_machines!(s.strip) }
                       .flatten
        elsif @machine_synced_folders.key?(search_string)
          [search_string]
        end
      unless machines && !machines.empty?
        raise MachineNotFoundError.new(search_string, @vagrantfile_dir)
      end
      machines
    end

    def first_machine
      first = @machine_synced_folders.first
      first ? first[0] : 'default'
    end

    def collect_folders_by_machine
      if @machine_synced_folders.empty?
        { 'default' => default_synced_folders }
      else
        folders = @machine_synced_folders.map do |name, synced_folders|
          [name, merge_with_defaults(synced_folders)]
        end

        # Sort the primary machine to the top, since it should be matched first
        if @primary_machine
          folders.sort_by! { |f| f[0] == @primary_machine ? 0 : 1 }
        end

        Hash[folders]
      end
    end

    private

    def match_machines_by_regexp(pattern)
      begin
        regex = Regexp.new(pattern)
      rescue RegexpError => e
        raise MachineRegexpError, e
      end
      @machine_synced_folders.keys.select { |name| name =~ regex }
    end

    def default_synced_folders
      defaults = @global_synced_folders
                 .reject { |_, opts| opts[:disabled] }
                 .map { |guest_path, opts| [guest_path, opts[:host_path]] }
      add_vagrant_default(Hash[defaults])
    end

    def add_vagrant_default(synced_folders)
      # Add default /vagrant share (see https://github.com/mitchellh/vagrant/blob/v1.8.4/plugins/kernel_v2/config/vm.rb#L511)
      if !synced_folders.key?('/vagrant') &&
         !synced_folders.value?(@vagrantfile_dir)
        synced_folders['/vagrant'] = @vagrantfile_dir
      end
      synced_folders
    end

    def merge_with_defaults(synced_folders)
      default_synced_folders.tap do |merged|
        synced_folders.each do |guest_path, opts|
          if opts[:disabled]
            merged.delete(guest_path)
            next
          end
          merged.delete('/vagrant') if opts[:host_path] == @vagrantfile_dir
          merged[guest_path] = opts[:host_path]
        end
      end
    end
  end
end
