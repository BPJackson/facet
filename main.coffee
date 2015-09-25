@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Meteor.methods
    delete: (postId)-> Posts.remove postId

if Meteor.isClient
    selectedtags = new ReactiveArray []
    Session.setDefault 'editing', null
    Session.setDefault 'view', null

    Template.nav.onCreated ->
        @autorun -> Meteor.subscribe 'tags', selectedtags.array(), Session.get 'authorFilter'

    Template.home.onCreated ->
        @autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get('authorFilter'), Session.get('editing')
        @subscribe 'people'

    Template.nav.onRendered ->
        self = @
        $('#mainfilter').dropdown
            allowAdditions: true
            duration: 0
            placeholder: 'filter'
            action: (text, value)-> selectedtags.push value
        Meteor.setTimeout ->
            $('.ui.dropdown').dropdown('show')
        , 300
        return

    Template.home.helpers
        posts: -> Posts.find {}
        user: -> Meteor.user()

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() is @authorId
        postTagClass: -> if @valueOf() in selectedtags.array() then 'active' else ''

    Template.nav.helpers
        tags: -> Tags.find()
        selectedtags: -> selectedtags.list()
        user: -> Meteor.user()

    Template.nav.events
        'click #add': ->
            newId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                }

            Session.set 'editing', newId
            Session.set 'authorFilter', null
            selectedtags.clear()

        'click #toggleOff': ->
            selectedtags.remove @toString()
            $('.ui.dropdown').dropdown('show')

    Template.post.events
        'click #edit': (e,t)-> Session.set 'editing', @_id

        'click #clone': (e,t)->
            Session.set 'view', null
            Session.set 'authorFilter', null
            selectedtags.clear()

            cloneId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                body: @body
                tags: @tags
                }
            Session.set 'editing', cloneId

        'click #save': (e,t)->
            body = t.find('textarea').value
            tags = $('.ui.dropdown').dropdown('get value')
            tags_lower = tags.map (tag)-> tag.toLowerCase()
            Posts.update @_id, $set: body: body, tags: tags_lower
            Session.set 'editing', null

            selectedtags.clear()
            tags_lower.forEach (tag)-> selectedtags.push tag

        'click #author': ->
            Session.set 'authorFilter',@authorId

        'click #delete': ->
            Meteor.call 'delete', @_id, ->
            selectedtags.clear()
            Session.set 'editing', null

        'click .postTag': (e)->
            Session.set 'editing', null
            if @toString() not in selectedtags.array()
                selectedtags.push @toString()
                $('.ui.dropdown').dropdown('show')
            else
                selectedtags.remove @toString()
                $('.ui.dropdown').dropdown('show')

    Template.edit.onRendered ->
        self = @
        $ ->
            $('#tagselector').dropdown
                allowAdditions: true
                placeholder: 'add tags'

            $('#editarea').editable
                inlineMode: false
                minHeight: 100
                toolbarFixed: false
                buttons: [
                    'bold'
                    'italic'
                    'underline'
                    #'strikeThrough'
                    #'subscript'
                    #'superscript'
                    #'fontFamily'
                    #'fontSize'
                    #'color'
                    'formatBlock'
                    #'blockStyle'
                    #'inlineStyle'
                    'align'
                    'insertOrderedList'
                    'insertUnorderedList'
                    'outdent'
                    'indent'
                    #'selectAll'
                    'createLink'
                    'insertImage'
                    'insertVideo'
                    'table'
                    #'undo'
                    #'redo'
                    'html'
                    #'save'
                    #'insertHorizontalRule'
                    #'uploadFile'
                    #'removeFormat'
                    'fullscreen'
                    ]
           return

if Meteor.isServer
    Posts.allow
        insert: (userId, post)-> post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', -> Meteor.users.find {}, fields: username: 1

    Meteor.publish 'tags', (selectedtags, authorFilter)->
        self = @
        match = {}

        if authorFilter? then match.authorId= authorFilter
        if selectedtags?.length > 0 then match.tags= $all: selectedtags

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedtags }
            { $sort: count: -1, _id: 1 }
            { $limit: 7 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()

    Meteor.publish 'posts', (selectedtags, authorFilter, editing)->
        if editing? then return Posts.find editing
        match = {}
        if authorFilter? then match.authorId= authorFilter
        if selectedtags?.length > 0 then match.tags= $all: selectedtags else Posts.find {}, {sort: timestamp: -1}, limit: 7
        return Posts.find match, limit: 7