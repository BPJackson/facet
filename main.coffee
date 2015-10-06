@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Meteor.methods
    delete: (postId)-> Posts.remove postId

Posts.helpers
    author: (doc)-> Meteor.users.findOne @authorId

if Meteor.isClient
    selectedTags = new ReactiveArray []
    selectedAuthor = new ReactiveArray []

    Session.setDefault 'editing', null

    Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'

    Template.nav.onCreated -> @autorun -> Meteor.subscribe 'tags', selectedTags.array(), selectedAuthor.array(), Session.get 'editing'

    Template.posts.onCreated ->
        @autorun -> Meteor.subscribe 'posts', selectedTags.array(), selectedAuthor.array(), Session.get('editing')
        @subscribe 'people'

    Template.nav.helpers
        displayedtags: -> Tags.find {}
        selectedTags: -> selectedTags.list()
        selectedAuthor: -> selectedAuthor.list()
        settings: -> {
            position: 'bottom'
            limit: 5
            rules: [{
                collection: Tags
                field: 'name'
                template: Template.tagresult
                }]
            }

    Template.posts.helpers posts: -> Posts.find {}

    Template.nav.events
        'autocompleteselect input': (event, template, doc)->
             selectedTags.push doc.name.toString()
             $('input').val('')

        'keyup #search': (event, template)->
             code = event.which
             if code is 13
                 val = $('#search').val()
                 switch val
                     when 'clear'
                         selectedTags.clear()
                         selectedAuthor.clear()
                         $('#search').val('')
                     when 'add'
                         Session.set 'adding', true
                         tags = selectedTags.array()
                         newId = Posts.insert {
                             authorId: Meteor.userId()
                             timestamp: Date.now()
                             tags: tags
                             }
                         Session.set 'editing', newId
                         $('#search').val('')
                     when 'mine'
                         if Meteor.user().username not in selectedAuthor.array()
                             selectedAuthor.push Meteor.user().username
                             $('#search').val('')
                     when 'logout'
                         Meteor.logout()
                         $('#search').val('')
         false


        'click #mine': -> if Meteor.user().username not in selectedAuthor.array() then selectedAuthor.push Meteor.user().username

        'click #add': ->
            Session.set 'adding', true

            #tags = selectedTags.array()
            newId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                #tags: tags
                }

            Session.set 'editing', newId

        'click .hometag': -> selectedTags.push @name.toString()

        'click .toggleOff': -> selectedTags.remove @toString()

        'click .unselectAuthor': -> selectedAuthor.remove @toString()

        'click #clear': ->
            selectedTags.clear()
            selectedAuthor.clear()


    Template.post.events
        'click #edit': (e,t)-> Session.set 'editing', @_id

        'click .clone': (e,t)->
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
            tags = $('.ui.multiple.dropdown').dropdown('get value')
            tagcount = tags.length

            loweredtags = tags.map (tag)-> tag.toLowerCase()

            Posts.update @_id, {$set: body: body, tags: loweredtags, tagcount: tagcount}, ->
            Session.set 'editing', null

            selectedTags.clear()
            loweredtags.forEach (tag)-> selectedTags.push tag

        'click #cancel': ->
            if Session.equals 'adding', true then Session.set 'adding', false
            Session.set 'editing', null

        'click #delete': ->
            Meteor.call 'delete', @_id, ->
            Session.set 'editing', null

        'click .posttag': (e)->
            Session.set 'editing', null
            if @toString() not in selectedTags.array()
                selectedTags.push @toString()
            else
                selectedTags.remove @toString()

        'click .author': (e)->
            if @author().username not in selectedAuthor.array() then selectedAuthor.push @author().username
            else selectedAuthor.remove @author().username

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() and Meteor.userId() is @authorId
        posttagclass: -> if @valueOf() in selectedTags.array() then 'active' else ''
        authorButtonClass: -> if @author().username in selectedAuthor.array() then 'active' else ''


    Template.edit.helpers
        editorOptions: ->
            {
                lineNumbers: true
                keymap: 'sublime'
                mode: 'gfm'
                indentBlock: 4
                lineWrapping: true
                viewportMargin: Infinity
            }

    Template.edit.onRendered ->
        $('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'press enter after each tag'
        return

if Meteor.isServer
    Posts.allow
        insert: (userId, post)-> userId and post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', -> Meteor.users.find {}, fields: username: 1

    Meteor.publish 'tags', (selectedTags, selectedAuthor)->
        self = @
        match = {}

        if selectedTags?.length > 0 then match.tags = $all: selectedTags

        if selectedAuthor?.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedTags }
            { $sort: count: -1, _id: 1 }
            { $limit: 100 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()

    Meteor.publish 'posts', (selectedTags, selectedAuthor, editing)->
        if editing? then return Posts.find editing

        match = {}

        #if selectedTags.length > 0 then match.tags = $all: selectedTags, $size: selectedTags.length else return null
        if selectedTags.length > 0 then match.tags = $all: selectedTags else return null

        if selectedAuthor?.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id

        return Posts.find match, limit: 7, sort: tagcount: 1