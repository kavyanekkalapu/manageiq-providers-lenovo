module ManageIQ::Providers::Lenovo
  class PhysicalInfraManager::Parser::PhysicalSwitchParser < PhysicalInfraManager::Parser::ComponentParser
    class << self
      #
      # Parses a switch into a Hash
      #
      # @param [XClarityClient::Switch] switch - object containing details for the switch
      #
      # @return [Hash] the switch data as required by the application
      #
      def parse_physical_switch(physical_switch)
        result = parse(physical_switch, parent::ParserDictionaryConstants::PHYSICAL_SWITCH)

        unless result[:power_state].nil?
          result[:power_state] = result[:power_state].downcase if %w(on off).include?(result[:power_state].downcase)
        end
        result[:type]         = parent::ParserDictionaryConstants::MIQ_TYPES["physical_switch"]
        result[:health_state] = parent::ParserDictionaryConstants::HEALTH_STATE_MAP[physical_switch.overallHealthState.nil? ? physical_switch.overallHealthState : physical_switch.overallHealthState.downcase]
        result[:hardware]     = get_hardwares(physical_switch)

        result[:asset_detail][:part_number]            = physical_switch.partNumber.presence&.strip
        result[:asset_detail][:field_replaceable_unit] = physical_switch.FRU.presence&.strip

        return physical_switch.uuid, result
      end

      private

      def get_hardwares(physical_switch)
        {
          :firmwares     => get_firmwares(physical_switch),
          :guest_devices => get_ports(physical_switch),
          :networks      => get_networks(physical_switch)
        }
      end

      def get_ports(physical_switch)
        physical_switch.ports&.map { |port| parse_port(port) }
      end

      def get_networks(physical_switch)
        get_parsed_switch_ip_interfaces_by_key(
          physical_switch.ipInterfaces,
          'IPv4assignments',
          physical_switch.ipv4Addresses,
          false
        ) + get_parsed_switch_ip_interfaces_by_key(
          physical_switch.ipInterfaces,
          'IPv6assignments',
          physical_switch.ipv6Addresses,
          true
        )
      end

      def get_parsed_switch_ip_interfaces_by_key(ip_interfaces, key, address_list, is_ipv6 = false)
        ip_interfaces&.flat_map { |interface| interface[key] }
          .select { |assignment| address_list.include?(assignment['address']) }
          .map { |assignment| parse_network(assignment, is_ipv6) }
      end

      def parse_network(assignment, is_ipv6 = false)
        result = parse(assignment, parent::ParserDictionaryConstants::PHYSICAL_SWITCH_NETWORK)

        result[:ipaddress]   = assignment['address'] unless is_ipv6
        result[:ipv6address] = assignment['address'] if is_ipv6

        result
      end

      def parse_port(port)
        {
          :device_name      => port["portName"].presence || port["port"],
          :device_type      => "physical_port",
          :peer_mac_address => port["peerMacAddress"].presence,
          :vlan_key         => port["PVID"].presence,
          :vlan_enabled     => port["PVID"].present?
        }
      end

      def get_firmwares(physical_switch)
        physical_switch.firmware&.map { |firmware| parent::FirmwareParser.parse_firmware(firmware) }
      end
    end
  end
end