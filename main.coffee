@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Items.helpers
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    clickup: (itemId)->

        item = Items.findOne itemId
        uid = Meteor.userId()

        #toggle if downd
        if item.downers.indexOf(uid) > -1
            Items.update itemId,
                $pull: downers: uid
                $addToSet: uppers: uid
                $inc: downs: -1, points: 2, ups: 1
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: 2

        #undo if upd
        else if item.uppers.indexOf(uid) > -1
            Items.update itemId,
                $pull: uppers: uid
                $inc: ups: -1, points: -1
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: -1

        #clean down
        else
            Items.update itemId,
                $inc: points: 1, ups: 1
                $addToSet: uppers: uid
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: 1

    clickdown: (itemId)->

        item = Items.findOne itemId
        uid = Meteor.userId()

        #toggle if upd
        if item.uppers.indexOf(uid) > -1
            Items.update itemId,
                $pull: uppers: uid
                $addToSet: downers: uid
                $inc: ups: -1, points: -2, downs: 1
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: -2


        #undo if downd
        else if item.downers.indexOf(uid) > -1
            Items.update itemId,
                $pull: downers: uid
                $inc: downs: -1, points: 1
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: 1

        #clean down
        else
            Items.update itemId,
                $inc: points: -1, downs: 1
                $addToSet: downers: uid
            #inc item authors points
            Meteor.users.update item.authorId,
                $inc: points: -1

    makeDayAuction: (itemId)->
        item = Items.findOne itemId
        dayFromNow = Date.now()+86400000
        Items.update itemId,
            $addToSet: tags: 'day auction'
            $unset: ups:'',uppers:'',downs:'',downers:'',points:''
            $set: isAuction: true, auctionEnd: dayFromNow, highBid: 0, highBidder: ''

Items.before.insert (userId, doc) ->
    doc.timestamp = Date.now()
    doc.authorId = Meteor.userId()
    doc.ups = 0
    doc.uppers = []
    doc.downs = 0
    doc.downers = []
    doc.points = 0

Meteor.users.before.insert

if Meteor.isClient
    Session.setDefault 'editing', null
    tagFilter = new ReactiveArray []
    authorFilter = new ReactiveArray []

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'
        #dropdownTransition: 'drop'
        #dropdownClasses: 'pointing'
    Tracker.autorun -> Meteor.subscribe 'tags', tagFilter.array(), authorFilter.array()
    Tracker.autorun -> Meteor.subscribe 'items', tagFilter.array(), authorFilter.array()
    Meteor.subscribe 'users'

    Template.home.onCreated ->
        $(window).on 'keyup', (e) ->
            if e.keyCode is 78 and e.shiftKey and e.altKey
                newId = Items.insert {}
                Session.set 'editing', newId

    Template.home.events
        'click .add': ->
            newId = Items.insert {}
            Session.set 'editing', newId
        'click .filterTag': -> tagFilter.push @name.toString()
        'click .unfilterTag': -> tagFilter.remove @toString()

        'click .unfilterAuthor': -> authorFilter.remove @toString()
        'click .userCloudTag': (e)-> if tagFilter.array().indexOf(@name) is -1 then tagFilter.push @name


    Template.home.helpers
        globalTags: ->
            itemCount = Items.find().count()
            Tags.find {count: $lt: itemCount}, limit: 10
        tagFilterList: -> tagFilter.list()
        authorFilterList: -> authorFilter.list()
        items: -> Items.find {}, sort: timestamp: -1
        user: -> Meteor.user()

    Template.item.helpers
        isAuction: -> @isAuction
        isEditing: -> Session.equals 'editing', @_id
        isAuthor: -> @authorId is Meteor.userId()

        canEdit: -> Meteor.userId()  is @authorId
        canClone: -> Meteor.userId()

        whenCreated: -> moment.utc(@timestamp).fromNow()
        whenEnd: -> moment.utc(@auctionEnd).fromNow()

        authorPoints: ->
            author = Meteor.users.findOne @authorId
            if author then author.points
        upButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''
        downButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''

        upIconClass: -> if @uppers.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'
        downIconClass: -> if @downers.indexOf(Meteor.userId()) > -1 then 'thumbs down' else 'thumbs down outline'

        authorButtonClass: ->
            if @author()
                name = @author().username
                if authorFilter.array().indexOf(name) > -1 then 'disabled' else ''

    Template.item.events
        'click .itemtag': (e)->
            tagName = e.target.textContent
            if tagFilter.array().indexOf(tagName) is -1 then tagFilter.push tagName

        'click .edit': (e,t)->
            $('.viewarea').dimmer('show')
            Session.set 'editing', @_id

        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val
            $('.viewarea').dimmer('hide')
            Session.set 'editing', null

        'click .clone': (e)->
            $('.viewarea').dimmer('show')
            cloneId = Items.insert {
                tags: @tags
                body: @body
                }
            Session.set 'editing', cloneId

        'click .username': (e)-> authorFilter.push @author().username

        'click .up': -> Meteor.call 'clickup', @_id
        'click .down': -> Meteor.call 'clickdown', @_id

        'click .delete': ->
            $('.viewarea').dimmer('hide')
            Items.remove @_id

    Template.editing.events
        'keyup input, keyup textarea':(e,t)->
            if (event.keyCode is 10 or event.keyCode is 13) and event.ctrlKey
                val = t.find('textarea').value
                Items.update @_id, $set: body: val
                $('.viewarea').dimmer('hide')
                Session.set 'editing', null

    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) ->

                switch addedValue
                    when 'delete this'
                        Items.remove self.data._id
                        $('.viewarea').dimmer('hide')
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    when 'day auction'
                        Meteor.call 'makeDayAuction', self.data._id
                        $('.viewarea').dimmer('hide')
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    else
                        Items.update self.data._id, $addToSet: tags: addedValue
                        Meteor.call 'calcUserCloud', Meteor.userId()


            onRemove: (removedValue) -> Items.update self.data._id, $pull: tags: removedValue

if Meteor.isServer

    Accounts.onCreateUser (options, user) ->
        user.points = 0
        user.cloud = []
        user

    Items.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> doc.authorId is userId
        remove: (userId, doc)-> doc.authorId is userId
        fetch: [ 'authorId' ]

    Meteor.methods
        calcUserCloud: (userId) ->
            userCloud = Items.aggregate [
                { $match: authorId: userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $sort: count: -1 }
                { $limit: 5 }
                { $project: _id: 0, name: '$_id', count: 1 }
                ]
            Meteor.users.update {_id:userId}, {$set: {cloud: userCloud} }


    Meteor.publish 'users', ->
        Meteor.users.find()

    Meteor.publish 'items', (tagFilter, authorFilter)->

        match = {}

        if tagFilter.length > 0 then match.tags= $all: tagFilter

        if authorFilter.length > 0
            author = Meteor.users.findOne username: authorFilter[0]
            match.authorId= author._id

        Items.find match, limit: 10

    Meteor.publish 'tags', (tagFilter, authorFilter)->
        me = @
        match = {}

        if tagFilter.length > 0 then match.tags= $all: tagFilter

        if authorFilter.length > 0
            author = Meteor.users.findOne username: authorFilter[0]
            match.authorId= author._id
        cloud = Items.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: tagFilter }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        cloud.forEach (tag) -> me.added 'tags', Random.id(), { name: tag.name, count:tag.count }
        me.ready()
