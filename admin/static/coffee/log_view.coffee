# Log view
module 'LogView', ->
    # LogView.Container
    class @Container extends Backbone.View
        className: 'log-view'
        template: Handlebars.compile $('#log-container-template').html()
        header_template: Handlebars.compile $('#log-header-template').html()
        max_log_entries: 20

        route: "/ajax/log/_?"

        displayed_logs: 0
        max_timestamp: 0

        log_route: '#logs'

        events: ->
            'click .next-log-entries': 'next_entries'
            'click .update-log-entries': 'update_log_entries'
            'click .expand_all': 'expand_all'

        initialize: (data) ->
            log_initial '(initializing) events view: container'

            if data?.route?
                @route = data.route
            if data?.template_header?
                @header_template = data.template_header
            if data?.filter?
                @filter = data.filter


            @current_logs = []
            
            @set_interval = setInterval @check_for_new_updates, updateInterval

        render: =>
            @.$el.html @template({})

            @fetch_log_entries
                max_length: @max_log_entries

            @.delegateEvents()

            return @

        fetch_log_entries: (url_params) =>
            route = @route
            for param, value of url_params
                route+="&#{param}=#{value}"
            $.getJSON route, @parse_log
            
        parse_log: (log_data_from_server) =>
            @max_timestamp = 0
            for machine_uuid, log_entries of log_data_from_server
                if @filter? and not @filter[machine_uuid]?
                    continue

                if log_entries.length > 0
                    @max_timestamp = parseFloat(log_entries[log_entries.length-1].timestamp) if @max_timestamp < parseFloat(log_entries[log_entries.length-1].timestamp)

                for json in log_entries # For each new log
                    log_saved = false
                    # Looking if it has been already added
                    for log, i in @current_logs
                        is_same_log = true
                        for attribute of log.attributes
                            if not json.attribute? or log.get(attribute) isnt json.attribute
                                is_same_log = false
                        if is_same_log
                            log_saved = true
                            break

                    # If it wasn't saved before, look if its place is IN the list 
                    if log_saved is false
                        for log, i in @current_logs
                            if parseFloat(json.timestamp) > parseFloat(log.get('timestamp'))
                                entry = new LogEntry json
                                entry.set('machine_uuid',machine_uuid)
                                @current_logs.splice i, 0, entry
                                log_saved = true
                                break

                    # If it's not, just add it ad the end
                    if log_saved is false
                        entry = new LogEntry json
                        entry.set('machine_uuid',machine_uuid)
                        @current_logs.push entry

            if @current_logs.length <= @displayed_logs
                @.$('.no-more-entries').show()
                @.$('.next-log-entries').hide()
            else
                for i in [0..@max_log_entries-1]
                    if @current_logs[@displayed_logs]?
                        view = new LogView.LogEntry
                            model: @current_logs[@displayed_logs]
                        @.$('.log-entries').append view.render().el
                        @displayed_logs++
                    else
                        @.$('.no-more-entries').show()
                        @.$('.next-log-entries').hide()
 
            @render_header()

        next_entries: (event) =>
            event.preventDefault()

            @fetch_log_entries
                max_length: @max_log_entries
                max_timestamp: @max_timestamp


        check_for_new_updates: =>
            min_timestamp = @current_logs[0].get('timestamp')
            if min_timestamp?
                route = @route+"&min_timestamp=#{min_timestamp}"

                @num_new_entries = 0
                $.getJSON route, (log_data_from_server) =>
                    for machine_uuid, log_entries of log_data_from_server
                        if @filter? and not @filter[machine_uuid]?
                            continue
                        @num_new_entries += log_entries.length
                    @render_header()

        render_header: =>
             @.$('.header').html @header_template
                new_entries: @num_new_entries > 0
                num_new_entries: @num_new_entries
                too_many_new_entries: @num_new_entries > @max_log_entries
                max_log_entries: @max_log_entries
                from_date: new XDate(@current_logs[0].get('timestamp')*1000).toString("MMMM M, yyyy 'at' HH:mm:ss")
                to_date: new XDate(@current_logs[@displayed_logs-1].get('timestamp')*1000).toString("MMMM M, yyyy 'at' HH:mm:ss")

        update_log_entries: (event) =>
            event.preventDefault()
            if @num_new_entries > @max_log_entries
                @render()
            else
                route = "/ajax/log/_?min_timestamp="+ @current_logs[0].get('timestamp')

                $.getJSON route, @parse_new_log

        parse_new_log: (log_data_from_server) =>
            for machine_uuid, log_entries of log_data_from_server
                if @filter? and not @filter[machine_uuid]?
                    continue


                for json in log_entries # For each new log
                    log_saved = false
                    for log, i in @current_logs
                        if parseFloat(json.timestamp) > parseFloat(log.get('timestamp'))
                            entry = new LogEntry json
                            entry.set('machine_uuid',machine_uuid)
                            @current_logs.splice i, 0, entry
                            log_saved = true
                            break

                    if log_saved is false
                        entry = new LogEntry json
                        entry.set('machine_uuid',machine_uuid)
                        @current_logs.push entry

            for i in [@num_new_entries-1..0]
                view = new LogView.LogEntry
                    model: @current_logs[i]
                rendered_view = $(view.render().el)
                rendered_view.css('background-color','#F8EEB1')
                @.$('.log-entries').prepend view.render().el
                rendered_view.animate
                    backgroundColor: '#FFF'
                , 2000
                @displayed_logs++

            @render_header()
            @.$('.header .alert').remove()

        expand_all: (event) =>
            event.preventDefault()
            if @.$(event.target).html() is 'Show all details'
                @.$(event.target).html 'Hide all details'
                @.$('.more-details-link').each ->
                    $(this).html 'Hide details'
                    $(this).parent().parent().next().next().slideDown 'fast'
            else
                @.$(event.target).html 'Show all details'
                @.$('.more-details-link').each ->
                    $(this).html 'More details'
                    $(this).parent().parent().next().next().slideUp 'fast'

        destroy: =>
            clearInterval @set_interval

    class @LogEntry extends Backbone.View
        className: 'log-entry'
        tagName: 'li'
        template: Handlebars.compile $('#log-entry-template').html()

        log_single_value_template: Handlebars.compile $('#log-single_value-template').html()
        log_machines_values_template: Handlebars.compile $('#log-machines_values-template').html()
        log_datacenters_values_template: Handlebars.compile $('#log-datacenters_values-template').html()
        log_shards_values_template: Handlebars.compile $('#log-shards_values-template').html()
        log_shards_list_values_template: Handlebars.compile $('#log-shards_list_values-template').html()
        log_new_namespace_template: Handlebars.compile $('#log-new_namespace-template').html()
        log_server_new_name_template: Handlebars.compile $('#log-server-new_name-template').html()
        log_server_set_datacenter_template: Handlebars.compile $('#log-server-set_datacenter-template').html()
        log_datacenter_new_name_template: Handlebars.compile $('#log-datacenter-new_name-template').html()

        events:
            'click .more-details-link': 'display_details'

        #TODO Check why it's not butter smooth.
        display_details: (event) =>
            event.preventDefault()
            if @.$(event.target).html() is 'More details'
                @.$(event.target).html 'Hide details'
                @.$(event.target).parent().parent().next().next().slideDown 'fast'
                
                # Check if we can show other details
                found_more_details_link = false
                $('.more-details-link').each ->
                    if $(this).html() is 'More details'
                        found_more_details_link = true
                        return false
                if found_more_details_link is false
                    $('.expand_all_link').html 'Hide all details'
            else
                @.$(event.target).html 'More details'
                @.$(event.target).parent().parent().next().next().slideUp 'fast'

                # Check if we can show other details
                found_hide_details_link = false
                $('.more-details-link').each ->
                    if $(this).html() is 'Hide details'
                        found_hide_details_link = true
                        return false
                if found_hide_details_link is false
                    $('.expand_all_link').html 'Show all details'

        render: =>
            json = _.extend @model.toJSON(), @format_msg(@model)
            #@model.get_formatted_message()
            json = _.extend json,
                machine_name: machines.get(@model.get('machine_uuid')).get('name')
                datetime: new XDate(@model.get('timestamp')*1000).toString("MMMM dd, yyyy 'at' HH:mm:ss")
        
            @.$el.html @template json 
            
            @delegateEvents()
            return @


        pattern_applying_data: /^(Applying data {)/
        format_msg: (model) =>
            msg = model.get('message')

            # Not sure if useful.
            # return '' if not msg?
            
            if @pattern_applying_data.test(msg)
                data = msg.slice 14
                msg = ''
                json_data = $.parseJSON data
                for group of json_data
                    switch group
                        when 'memcached_namespaces'
                            for namespace_id of json_data[group]
                                if namespace_id is 'new'
                                    msg += @log_new_namespace_template 
                                        namespace_name: json_data[group]['new']['name']
                                        datacenter_id: json_data[group]['new']['primary_uuid']
                                        datacenter_name: if datacenters.get(json_data[group]['new']['primary_uuid'])? then datacenters.get(json_data[group]['new']['primary_uuid']).get 'name' else 'removed datacenter'
                                        port: json_data[group]['new']['port']
                                else
                                    attributes = []
                                    for attribute of json_data[group][namespace_id]
                                        if attribute is 'ack_expectations' or attribute is 'replica_affinities'
                                            _datacenters = []
                                            for datacenter_id of json_data[group][namespace_id][attribute]
                                                _datacenters.push
                                                    datacenter_id: datacenter_id
                                                    datacenter_name: datacenters.get(datacenter_id).get 'name'
                                                    value: json_data[group][namespace_id][attribute][datacenter_id]
                                            msg += @log_datacenters_values_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: attribute
                                                datacenters: _datacenters
                                        else if attribute is 'name' or attribute is 'port'
                                            msg += @log_single_value_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: attribute
                                                value: json_data[group][namespace_id][attribute]
                                        else if attribute is 'primary_uuid'
                                            msg += @log_single_value_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: 'primary datacenter'
                                                datacenter_id: json_data[group][namespace_id][attribute]
                                                datacenter_name: datacenters.get(json_data[group][namespace_id][attribute]).get 'name'
                                        else if attribute is 'primary_pinnings'
                                            shards = []
                                            for shard of json_data[group][namespace_id][attribute]
                                                if json_data[group][namespace_id][attribute][shard]?
                                                    shards.push
                                                        shard: shard
                                                        machine_id:  json_data[group][namespace_id][attribute][shard]
                                                        machine_name: if machines.get(json_data[group][namespace_id][attribute][shard])? then  machines.get(json_data[group][namespace_id][attribute][shard]).get('name') else 'removed machine'
                                                else
                                                    shards.push
                                                        shard: shard
                                                        is_null: true

                                            msg += @log_shards_values_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: attribute
                                                shards: shards
                                        else if attribute is 'secondary_pinnings'
                                            shards = []
                                            for shard of json_data[group][namespace_id][attribute]
                                                _machines = []
                                                for machine_id in json_data[group][namespace_id][attribute][shard]
                                                    if machine_id?
                                                        _machines.push
                                                            id: machine_id
                                                            name: if machines.get(machine_id)? then machines.get(machine_id).get 'name' else 'removed machine'
                                                shards.push
                                                    shard: shard
                                                    machines: _machines
                                            msg += @log_shards_list_values_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: attribute
                                                shards: shards
                                        else if attribute is 'shards'
                                            value = [] # We could make thing faster later.
                                            for shard_string in json_data[group][namespace_id][attribute]
                                                value.push JSON.parse shard_string
                                            msg += @log_single_value_template
                                                namespace_id: namespace_id
                                                namespace_name: if namespaces.get(namespace_id)? then namespaces.get(namespace_id).get 'name' else 'removed namespace'
                                                attribute: attribute
                                                value: JSON.stringify(value).replace(/\\"/g,'"')



                        when 'machines'
                            for machine_id of json_data[group]
                                for attribute of json_data[group][machine_id]
                                    if attribute is 'name'
                                        msg += @log_server_new_name_template
                                            name: json_data[group][machine_id][attribute]
                                            machine_id: machine_id
                                            machine_id_trunked: machine_id.slice 24
                                    else if attribute is 'datacenter_uuid'
                                        msg += @log_server_set_datacenter_template
                                            machine_id: machine_id
                                            machine_name: if machines.get(machine_id)? then machines.get(machine_id).get('name') else 'removed machine'
                                            datacenter_id: json_data[group][machine_id][attribute]
                                            datacenter_name: if datacenters.get(json_data[group][machine_id][attribute])? then datacenters.get(json_data[group][machine_id][attribute]).get('name') else 'removed datacenter'
                        when 'datacenters'
                            for datacenter_id of json_data[group]
                                for attribute of json_data[group][datacenter_id]
                                    if attribute is 'name'
                                        msg += @log_datacenter_new_name_template
                                            name: json_data[group][datacenter_id][attribute]
                                            datacenter_id: machine_id
                                            datacenter_id_trunked: datacenter_id.slice 24
                                            name: json_data[group][datacenter_id][attribute]
                        #TODO logs for databases
                return {
                    msg: msg
                    raw_data: data
                }
            else
                return {
                    msg: msg
                }
