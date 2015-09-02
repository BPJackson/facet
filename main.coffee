@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Items.helpers
    author: -> Meteor.users.findOne @authorId
    bidder: -> if @bidderId then Meteor.users.findOne @bidderId


Meteor.methods
    vote: (itemId)->
        item = Items.findOne itemId
        me = Meteor.userId()

        #if already a voter, undo vote
        if item.voters.indexOf(me) > -1
            Items.update itemId, $inc: {votes: -1}, $pull: voters: me
            Meteor.users.update item.authorId, $inc: points: -1
            return

        else #if not a voter, vote
            Items.update itemId, $inc: {votes: 1}, $addToSet: voters: me
            Meteor.users.update item.authorId, $inc: points: 1
            return

    makeDayAuction: (itemId)->
        auction = Items.findOne itemId
        dayFromNow = Date.now() + 86400000
        Items.update itemId,
            $addToSet: tags: 'day auction'
            $unset: votes:'', voters:''
            $set: isAuction: true, auctionEnd: dayFromNow, bid: 0,


    bid: (itemId)->
        item = Items.findOne itemId

        Meteor.users.update item.bidderId, { $inc: points: item.bid }
        Meteor.users.update Meteor.userId(), { $inc: points: -(item.bid+1) }
        Meteor.users.update item.authorId, { $inc: points: 1 }

        Items.update itemId,
            $set: bidderId: Meteor.userId()
            $inc: bid: 1
        return

Items.before.insert (userId, doc) ->
    doc.timestamp = Date.now()
    doc.authorId = Meteor.userId()
    doc.voters = []
    doc.votes = 0

if Meteor.isClient
    Session.setDefault 'editing', null
    tagFilter = new ReactiveArray []
    authorFilter = new ReactiveArray []

    Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'
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

        canEdit: -> Meteor.userId() is @authorId

        whenCreated: -> moment.utc(@timestamp).fromNow()
        whenEnd: -> moment.utc(@auctionEnd).fromNow()

        authorPoints: ->
            author = Meteor.users.findOne @authorId
            if author then author.points

        voteButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''

        voteIconClass: -> if @voters.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'

        authorButtonClass: ->
            if @author()
                name = @author().username
                if authorFilter.array().indexOf(name) > -1 then 'disabled' else ''

        newBid: -> @bid + 1
        canBid: ->
            userId = Meteor.userId()
            if not userId then 'disabled'
            else if @authorId is Meteor.userId() then 'disabled'
            else if Meteor.user().points < @bid then 'disabled'
            else ''


    Template.item.events
        'click .itemtag': (e)->
            tagName = e.target.textContent
            if tagFilter.array().indexOf(tagName) is -1 then tagFilter.push tagName

        'click .edit': (e,t)->
            $('.viewarea').dimmer('show')
            Session.set 'editing', @_id

        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val, (err)-> if err then console.error err

            $('.viewarea').dimmer('hide')
            Session.set 'editing', null

        'click .username': (e)-> authorFilter.push @author().username

        'click .vote': -> Meteor.call 'vote', @_id

        'click .delete': ->
            $('.viewarea').dimmer('hide')
            Items.remove @_id

        'click .bid': ->
            Meteor.call 'bid', @_id

    Template.editing.events
        'keyup input, keyup textarea':(e,t)->
            #control-c to save body input
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
        update: (userId, doc)-> true
        remove: (userId, doc)-> doc.authorId is userId

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

            Meteor.users.update { _id: userId }, $set: cloud: userCloud


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
        self = @
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


        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
