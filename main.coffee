@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Meteor.methods
    delete: (postId)-> Posts.remove postId

if Meteor.isClient
    selectedtags = new ReactiveArray []

    Session.setDefault 'editing', null

    Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'


    Template.nav.onCreated -> @autorun -> Meteor.subscribe 'tags', selectedtags.array(), Session.get 'editing'

    #Template.nav.onRendered ->
        #self = @
        #$('#mainfilter').dropdown
            #allowAdditions: true
            #duration: 0
            #placeholder: 'filter'
            #action: (text, value)-> selectedtags.push value.toLowerCase()
        #Meteor.setTimeout ->
            #$('.ui.search.dropdown').dropdown('show')
        #, 300
        #return

    Template.nav.helpers
        dropdowntags: -> Tags.find {}, limit: 7
        tags: -> Tags.find()
        selectedtags: -> selectedtags.list()

    Template.nav.events
        'click #add': ->
            Session.set 'adding', true

            tags = selectedtags.array()
            newId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                tags: tags
                }

            Session.set 'editing', newId

        'click .hometag': -> selectedtags.push @name.toString()

        'click #toggleOff': ->
            selectedtags.remove @toString()
            #$('.ui.search.dropdown').dropdown('show')

        'click #clear': ->
            selectedtags.clear()
            #$('.ui.search.dropdown').dropdown('show')


    Template.posts.onCreated ->
        @autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get('editing')
        @subscribe 'people'

    Template.posts.helpers posts: -> Posts.find {}


    Template.post.events
        'click #edit': (e,t)-> Session.set 'editing', @_id

        'click #clone': (e,t)->
            cloneId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                body: @body
                tags: @tags
                }
            Session.set 'editing', cloneId

        'click #save': (e,t)->
            if Session.equals 'adding', true then Session.set 'adding', false
            body = t.find('#codebody').value
            #body = t.find('#editarea').value

            tags = $('.ui.multiple.dropdown').dropdown('get value')
            tagcount = tags.length

            loweredtags = tags.map (tag)-> tag.toLowerCase()

            Posts.update @_id, {$set: body: body, tags: loweredtags, tagcount: tagcount}, ->
            Session.set 'editing', null

            selectedtags.clear()
            loweredtags.forEach (tag)-> selectedtags.push tag

        'click #cancel': ->
            if Session.equals 'adding', true then Session.set 'adding', false
            Session.set 'editing', null

        'click #delete': ->
            Meteor.call 'delete', @_id, ->
            Session.set 'editing', null

        'click .posttag': (e)->
            Session.set 'editing', null
            if @toString() not in selectedtags.array()
                selectedtags.push @toString()
                #$('.ui.search.dropdown').dropdown('show')
            else
                selectedtags.remove @toString()
                #$('.ui.search.dropdown').dropdown('show')

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() is @authorId
        posttagclass: -> if @valueOf() in selectedtags.array() then 'active' else ''


    Template.edit.helpers
        editorOptions: ->
            {
                lineNumbers: true
                mode: 'gfm'
                indentBlock: 4
            }

    Template.edit.onRendered ->
        $('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'press enter after each tag'
            #onAdd: (val)-> selectedtags.push val.toLowerCase()
            #onRemove: (val)-> selectedtags.remove val.toLowerCase()
        return


    Template.home.helpers

    Template.home.events



if Meteor.isServer
    Posts.allow
        insert: (userId, post)-> userId and post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', -> Meteor.users.find {}, fields: username: 1

    Meteor.publish 'tags', (selectedtags)->
        self = @
        match = {}
        if selectedtags?.length > 0 then match.tags= $all: selectedtags

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedtags }
            { $sort: count: -1, _id: 1 }
            { $limit: 20 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()

    Meteor.publish 'posts', (selectedtags, editing)->
        if editing? then Posts.find editing
        else if selectedtags?.length > 0 then Posts.find {tags: $all: selectedtags}, limit: 1, sort: tagcount: 1 else null
        #else if selectedtags?.length > 0 then Posts.find {tags: $in: selectedtags}, limit: 1, sort: tagcount: 1 else null