require 'spec_helper'

describe Avsh::SshCommandExecutor do
  subject { described_class.new(double(debug: nil), 'foo_machine', '/s.sock') }

  context 'with non-empty command and a guest dir' do
    it 'changes to guest dir and executes command' do
      expect(Kernel).to receive(:exec).with('ssh', '-o ControlPath /s.sock',
                                            'foo_machine', 'cd /somedir; ls')
      expect { subject.execute('ls', '/somedir') }.to \
        raise_error(Avsh::ExecSshError)
    end
  end

  context 'with empty command and a guest dir' do
    it 'changes to guest dir and runs shell' do
      expect(Kernel).to receive(:exec).with('ssh', '-o ControlPath /s.sock',
                                            '-t', 'foo_machine',
                                            'cd /somedir; exec $SHELL -l')
      expect { subject.execute('', '/somedir') }.to \
        raise_error(Avsh::ExecSshError)
    end
  end

  context 'with non-empty command and no guest dir' do
    it 'runs command' do
      expect(Kernel).to receive(:exec).with('ssh', '-o ControlPath /s.sock',
                                            'foo_machine', 'pwd')
      expect { subject.execute('pwd') }.to raise_error(Avsh::ExecSshError)
    end
  end
end